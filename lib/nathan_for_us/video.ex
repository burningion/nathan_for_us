defmodule NathanForUs.Video do
  @moduledoc """
  The Video context for managing video processing and frame search functionality.
  """

  import Ecto.Query, warn: false
  alias NathanForUs.Repo

  alias NathanForUs.Video.{Video, VideoFrame, VideoCaption, FrameCaption}

  @doc """
  Creates a new video record.
  """
  def create_video(attrs \\ %{}) do
    %Video{}
    |> Video.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a video by ID.
  """
  def get_video!(id), do: Repo.get!(Video, id)

  @doc """
  Gets a video by file path.
  """
  def get_video_by_path(file_path) do
    Repo.get_by(Video, file_path: file_path)
  end

  @doc """
  Updates a video record.
  """
  def update_video(%Video{} = video, attrs) do
    video
    |> Video.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all videos.
  """
  def list_videos do
    Repo.all(Video)
  end

  @doc """
  Lists videos by status.
  """
  def list_videos_by_status(status) do
    Video
    |> where([v], v.status == ^status)
    |> Repo.all()
  end

  @doc """
  Creates video frames in batch for efficiency.
  """
  def create_frames_batch(video_id, frame_data) when is_list(frame_data) do
    frames = 
      frame_data
      |> Enum.map(fn frame_attrs ->
        frame_attrs
        |> Map.put(:video_id, video_id)
        |> Map.put(:inserted_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
        |> Map.put(:updated_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
      end)

    Repo.insert_all(VideoFrame, frames)
  end

  @doc """
  Creates video captions in batch for efficiency.
  """
  def create_captions_batch(video_id, caption_data) when is_list(caption_data) do
    captions = 
      caption_data
      |> Enum.map(fn caption_attrs ->
        caption_attrs
        |> Map.put(:video_id, video_id)
        |> Map.put(:inserted_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
        |> Map.put(:updated_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
      end)

    Repo.insert_all(VideoCaption, captions)
  end

  @doc """
  Searches for captions containing the given text using PostgreSQL full-text search.
  Returns frames associated with matching captions.
  """
  def search_frames_by_text(search_term) when is_binary(search_term) do
    query = """
    SELECT DISTINCT f.*, 
           string_agg(DISTINCT c.text, ' | ') as caption_texts
    FROM video_frames f
    JOIN frame_captions fc ON fc.frame_id = f.id
    JOIN video_captions c ON c.id = fc.caption_id
    WHERE to_tsvector('english', c.text) @@ plainto_tsquery('english', $1)
    GROUP BY f.id, f.video_id, f.frame_number, f.timestamp_ms, f.file_path, f.file_size, f.width, f.height, f.image_data, f.compression_ratio, f.inserted_at, f.updated_at
    ORDER BY f.timestamp_ms
    """
    
    Ecto.Adapters.SQL.query!(Repo, query, [search_term])
    |> map_frame_results_with_captions()
  end

  @doc """
  Searches for captions containing the given text using simple ILIKE search.
  Fallback for when full-text search is not available.
  """
  def search_frames_by_text_simple(search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    query = """
    SELECT DISTINCT f.*, 
           string_agg(DISTINCT c.text, ' | ') as caption_texts
    FROM video_frames f
    JOIN frame_captions fc ON fc.frame_id = f.id
    JOIN video_captions c ON c.id = fc.caption_id
    WHERE c.text ILIKE $1
    GROUP BY f.id, f.video_id, f.frame_number, f.timestamp_ms, f.file_path, f.file_size, f.width, f.height, f.image_data, f.compression_ratio, f.inserted_at, f.updated_at
    ORDER BY f.timestamp_ms
    """
    
    Ecto.Adapters.SQL.query!(Repo, query, [search_pattern])
    |> map_frame_results_with_captions()
  end

  @doc """
  Gets frames for a specific video within a time range.
  """
  def get_frames_by_time_range(video_id, start_ms, end_ms) do
    VideoFrame
    |> where([f], f.video_id == ^video_id)
    |> where([f], f.timestamp_ms >= ^start_ms and f.timestamp_ms <= ^end_ms)
    |> order_by([f], f.timestamp_ms)
    |> Repo.all()
  end

  @doc """
  Gets captions for a specific video within a time range.
  """
  def get_captions_by_time_range(video_id, start_ms, end_ms) do
    VideoCaption
    |> where([c], c.video_id == ^video_id)
    |> where([c], c.start_time_ms <= ^end_ms and c.end_time_ms >= ^start_ms)
    |> order_by([c], c.start_time_ms)
    |> Repo.all()
  end

  @doc """
  Links frames to captions based on timestamp overlap.
  This should be called after both frames and captions are created.
  """
  def link_frames_to_captions(video_id) do
    # Get all frames and captions for the video
    frames = Repo.all(from f in VideoFrame, where: f.video_id == ^video_id)
    captions = Repo.all(from c in VideoCaption, where: c.video_id == ^video_id)

    # Create associations based on timestamp overlap
    associations = 
      for frame <- frames,
          caption <- captions,
          frame.timestamp_ms >= caption.start_time_ms and 
          frame.timestamp_ms <= caption.end_time_ms do
        %{
          frame_id: frame.id,
          caption_id: caption.id,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end

    if length(associations) > 0 do
      Repo.insert_all(FrameCaption, associations)
    else
      {0, []}
    end
  end

  @doc """
  Gets frame count statistics for a video.
  """
  def get_frame_stats(video_id) do
    VideoFrame
    |> where([f], f.video_id == ^video_id)
    |> select([f], %{
      count: count(f.id),
      min_timestamp: min(f.timestamp_ms),
      max_timestamp: max(f.timestamp_ms)
    })
    |> Repo.one()
  end

  @doc """
  Gets caption statistics for a video.
  """
  def get_caption_stats(video_id) do
    VideoCaption
    |> where([c], c.video_id == ^video_id)
    |> select([c], %{
      count: count(c.id),
      total_duration: sum(c.end_time_ms - c.start_time_ms),
      min_start_time: min(c.start_time_ms),
      max_end_time: max(c.end_time_ms)
    })
    |> Repo.one()
  end

  # Private helper functions

  defp map_frame_results(%{rows: rows, columns: columns}) do
    Enum.map(rows, fn row ->
      columns
      |> Enum.zip(row)
      |> Enum.into(%{})
      |> atomize_keys()
    end)
  end

  defp map_frame_results_with_captions(%{rows: rows, columns: columns}) do
    Enum.map(rows, fn row ->
      frame_data = columns
      |> Enum.zip(row)
      |> Enum.into(%{})
      |> atomize_keys()
      
      # Extract caption_texts and add it as a separate field
      caption_texts = Map.get(frame_data, :caption_texts, "")
      Map.put(frame_data, :caption_texts, caption_texts)
    end)
  end

  defp atomize_keys(map) when is_map(map) do
    for {key, value} <- map, into: %{} do
      {String.to_atom(key), value}
    end
  end

  @doc """
  Gets the binary image data for a specific frame.
  """
  def get_frame_image_data(frame_id) do
    case Repo.get(VideoFrame, frame_id) do
      %VideoFrame{image_data: image_data} when not is_nil(image_data) ->
        {:ok, image_data}
      
      %VideoFrame{image_data: nil} ->
        {:error, :no_image_data}
      
      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Migrates existing frames from file paths to binary storage with compression.
  """
  def migrate_frames_to_binary(video_id, jpeg_quality \\ 75) do
    frames = VideoFrame
    |> where([f], f.video_id == ^video_id)
    |> where([f], is_nil(f.image_data))  # Only migrate frames without binary data
    |> where([f], not is_nil(f.file_path))  # Only frames with file paths
    |> Repo.all()

    migrated_count = 
      frames
      |> Enum.map(fn frame ->
        case NathanForUs.VideoProcessor.compress_jpeg_file(frame.file_path, jpeg_quality) do
          {:ok, compressed_data, compression_ratio} ->
            frame
            |> Ecto.Changeset.change(%{
              image_data: compressed_data,
              compression_ratio: compression_ratio,
              file_size: byte_size(compressed_data)
            })
            |> Repo.update()
            
            1  # Count successful migration
          
          {:error, reason} ->
            require Logger
            Logger.warning("Failed to compress frame #{frame.id}: #{inspect(reason)}")
            0  # Count failed migration
        end
      end)
      |> Enum.sum()

    {:ok, migrated_count}
  end
end