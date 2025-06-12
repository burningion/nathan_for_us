defmodule NathanForUsWeb.Api.VideoUploadController do
  use NathanForUsWeb, :controller

  alias NathanForUs.Video
  alias NathanForUs.Repo

  @doc """
  Accepts a complete video dataset and uploads it to production.
  Expected payload format:
  {
    "video": {
      "title": "string",
      "file_path": "string", 
      "duration_ms": integer,
      "fps": float,
      "frame_count": integer,
      "metadata": map
    },
    "frames": [
      {
        "frame_number": integer,
        "timestamp_ms": integer,
        "file_path": "string (optional)",
        "file_size": integer,
        "width": integer,
        "height": integer,
        "image_data": "base64 encoded binary data",
        "compression_ratio": float
      }
    ],
    "captions": [
      {
        "start_time_ms": integer,
        "end_time_ms": integer,
        "text": "string",
        "caption_index": integer
      }
    ]
  }
  """
  def upload(conn, params) do
    case upload_video_data(params) do
      {:ok, video} ->
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          video_id: video.id,
          message: "Video uploaded successfully",
          stats: get_upload_stats(video.id)
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          errors: format_changeset_errors(changeset)
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: to_string(reason)
        })
    end
  end

  defp upload_video_data(%{"video" => video_params, "frames" => frames_params, "captions" => captions_params}) do
    # First, try to get or create the video outside transaction
    video_attrs = prepare_video_attrs(video_params)
    video = case Video.create_video(video_attrs) do
      {:ok, video} -> 
        video
      {:error, changeset} ->
        # Check if it's a duplicate file_path error
        case changeset.errors[:file_path] do
          {"has already been taken", _} ->
            # Find existing video by file_path
            case Video.get_video_by_file_path(video_attrs.file_path) do
              nil -> {:error, changeset}
              existing_video -> existing_video
            end
          _ ->
            {:error, changeset}
        end
    end

    case video do
      {:error, changeset} -> {:error, changeset}
      video ->
        # Now run the transaction for captions/frames
        Repo.transaction(fn ->
          # Clear existing frames and captions for this video
          Video.delete_video_frames(video.id)
          Video.delete_video_captions(video.id)

          # Create captions first (frames reference them)
          caption_attrs = prepare_captions_attrs(captions_params, video.id)
          captions = create_captions_batch(caption_attrs)

          # Create frames with image data
          frame_attrs = prepare_frames_attrs(frames_params, video.id)
          frames = create_frames_batch(frame_attrs)

          # Link frames to captions based on timestamp overlap
          link_frames_to_captions(frames, captions)

          # Update video status to completed
          case Video.update_video(video, %{status: "completed", processed_at: DateTime.utc_now()}) do
            {:ok, updated_video} -> updated_video
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
    end
  end

  defp upload_video_data(_), do: {:error, "Invalid payload format"}

  defp prepare_video_attrs(video_params) do
    %{
      title: video_params["title"],
      file_path: video_params["file_path"],
      duration_ms: video_params["duration_ms"],
      fps: video_params["fps"],
      frame_count: video_params["frame_count"],
      metadata: video_params["metadata"] || %{},
      status: "processing"
    }
  end

  defp prepare_captions_attrs(captions_params, video_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    
    Enum.map(captions_params, fn caption ->
      %{
        video_id: video_id,
        start_time_ms: caption["start_time_ms"],
        end_time_ms: caption["end_time_ms"],
        text: caption["text"],
        caption_index: caption["caption_index"],
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp prepare_frames_attrs(frames_params, video_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    
    Enum.map(frames_params, fn frame ->
      image_data = case frame["image_data"] do
        nil -> nil
        base64_data -> Base.decode64!(base64_data)
      end

      %{
        video_id: video_id,
        frame_number: frame["frame_number"],
        timestamp_ms: frame["timestamp_ms"],
        file_path: frame["file_path"],
        file_size: frame["file_size"],
        width: frame["width"],
        height: frame["height"],
        image_data: image_data,
        compression_ratio: frame["compression_ratio"],
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp create_captions_batch(caption_attrs) do
    Repo.insert_all(Video.VideoCaption, caption_attrs, returning: true)
    |> elem(1)
  end

  defp create_frames_batch(frame_attrs) do
    Repo.insert_all(Video.VideoFrame, frame_attrs, returning: true)
    |> elem(1)
  end

  defp link_frames_to_captions(frames, captions) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    
    frame_caption_links = 
      for frame <- frames,
          caption <- captions,
          frame_in_caption_timerange?(frame, caption) do
        %{
          frame_id: frame.id,
          caption_id: caption.id,
          inserted_at: now,
          updated_at: now
        }
      end

    if frame_caption_links != [] do
      Repo.insert_all(Video.FrameCaption, frame_caption_links)
    end
  end

  defp frame_in_caption_timerange?(frame, caption) do
    frame.timestamp_ms >= caption.start_time_ms and
    frame.timestamp_ms <= caption.end_time_ms
  end

  defp get_upload_stats(video_id) do
    %{
      frame_count: Video.count_video_frames(video_id),
      caption_count: Video.count_video_captions(video_id),
      frame_caption_links: Video.count_frame_caption_links(video_id)
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end