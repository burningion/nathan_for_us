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
  Gets a video by ID (returns {:ok, video} or {:error, :not_found}).
  """
  def get_video(id) do
    case Repo.get(Video, id) do
      nil -> {:error, :not_found}
      video -> {:ok, video}
    end
  end

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
  Gets a video by file path.
  """
  def get_video_by_file_path(file_path) do
    Repo.get_by(Video, file_path: file_path)
  end

  @doc """
  Deletes all frames for a video.
  """
  def delete_video_frames(video_id) do
    VideoFrame
    |> where([f], f.video_id == ^video_id)
    |> Repo.delete_all()
  end

  @doc """
  Deletes all captions for a video.
  """
  def delete_video_captions(video_id) do
    VideoCaption
    |> where([c], c.video_id == ^video_id)
    |> Repo.delete_all()
  end

  @doc """
  Gets all captions for a video.
  """
  def get_video_captions(video_id) do
    VideoCaption
    |> where([c], c.video_id == ^video_id)
    |> order_by([c], c.start_time_ms)
    |> Repo.all()
  end

  @doc """
  Gets video frames with pagination.
  """
  def get_video_frames_with_pagination(video_id, offset \\ 0, limit \\ 20) do
    frames =
      VideoFrame
      |> where([f], f.video_id == ^video_id)
      |> order_by([f], f.frame_number)
      |> offset(^offset)
      |> limit(^limit)
      |> Repo.all()

    total_count =
      VideoFrame
      |> where([f], f.video_id == ^video_id)
      |> select([f], count(f.id))
      |> Repo.one()

    {:ok, %{frames: frames, total_count: total_count}}
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
        |> Map.put(
          :inserted_at,
          DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
        )
        |> Map.put(
          :updated_at,
          DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
        )
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
        |> Map.put(
          :inserted_at,
          DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
        )
        |> Map.put(
          :updated_at,
          DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
        )
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
           v.title as video_title,
           string_agg(DISTINCT c.text, ' | ') as caption_texts
    FROM video_frames f
    JOIN videos v ON v.id = f.video_id
    JOIN frame_captions fc ON fc.frame_id = f.id
    JOIN video_captions c ON c.id = fc.caption_id
    WHERE c.text ILIKE $1
    GROUP BY f.id, f.video_id, f.frame_number, f.timestamp_ms, f.file_path, f.file_size, f.width, f.height, f.image_data, f.compression_ratio, f.inserted_at, f.updated_at, v.title
    ORDER BY v.title, f.timestamp_ms
    """

    Ecto.Adapters.SQL.query!(Repo, query, [search_pattern])
    |> map_frame_results_with_captions()
  end

  @doc """
  Searches for captions containing the given text using simple ILIKE search within multiple specific videos.
  """
  def search_frames_by_text_simple_filtered(search_term, video_ids)
      when is_binary(search_term) and is_list(video_ids) do
    search_pattern = "%#{search_term}%"

    query = """
    SELECT DISTINCT f.*, 
           v.title as video_title,
           string_agg(DISTINCT c.text, ' | ') as caption_texts
    FROM video_frames f
    JOIN videos v ON v.id = f.video_id
    JOIN frame_captions fc ON fc.frame_id = f.id
    JOIN video_captions c ON c.id = fc.caption_id
    WHERE c.text ILIKE $1 AND f.video_id = ANY($2)
    GROUP BY f.id, f.video_id, f.frame_number, f.timestamp_ms, f.file_path, f.file_size, f.width, f.height, f.image_data, f.compression_ratio, f.inserted_at, f.updated_at, v.title
    ORDER BY v.title, f.timestamp_ms
    """

    Ecto.Adapters.SQL.query!(Repo, query, [search_pattern, video_ids])
    |> map_frame_results_with_captions()
  end

  @doc """
  Searches for captions containing the given text using simple ILIKE search within a specific video.
  """
  def search_frames_by_text_simple(search_term, video_id)
      when is_binary(search_term) and is_integer(video_id) do
    search_pattern = "%#{search_term}%"

    query = """
    SELECT DISTINCT f.*, 
           string_agg(DISTINCT c.text, ' | ') as caption_texts
    FROM video_frames f
    JOIN frame_captions fc ON fc.frame_id = f.id
    JOIN video_captions c ON c.id = fc.caption_id
    WHERE c.text ILIKE $1 AND f.video_id = $2
    GROUP BY f.id, f.video_id, f.frame_number, f.timestamp_ms, f.file_path, f.file_size, f.width, f.height, f.image_data, f.compression_ratio, f.inserted_at, f.updated_at
    ORDER BY f.timestamp_ms
    """

    Ecto.Adapters.SQL.query!(Repo, query, [search_pattern, video_id])
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
          inserted_at:
            DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
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

  defp map_frame_results_with_captions(%{rows: rows, columns: columns}) do
    Enum.map(rows, fn row ->
      frame_data =
        columns
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
  Records that frames were used in GIF generation to boost cache priority.
  """
  def record_frames_gif_usage(frame_ids) when is_list(frame_ids) do
    Enum.each(frame_ids, fn frame_id ->
      NathanForUs.FrameCache.record_gif_usage(frame_id)
    end)
  end

  @doc """
  Gets frames by their IDs for cache warming.
  """
  def get_frames_by_ids(frame_ids) when is_list(frame_ids) do
    VideoFrame
    |> where([f], f.id in ^frame_ids)
    |> Repo.all()
  end

  @doc """
  Gets captions for a GIF based on its frame IDs.
  Returns unique caption texts that appear during the GIF timeframe.
  """
  def get_gif_captions(frame_ids) when is_list(frame_ids) and length(frame_ids) > 0 do
    query = """
    SELECT DISTINCT c.text
    FROM video_captions c
    JOIN frame_captions fc ON fc.caption_id = c.id
    WHERE fc.frame_id = ANY($1)
    ORDER BY c.text
    """

    case Ecto.Adapters.SQL.query(Repo, query, [frame_ids]) do
      {:ok, %{rows: rows}} ->
        rows |> Enum.map(fn [text] -> text end) |> Enum.take(10)  # Limit to prevent overwhelming UI
      {:error, _reason} ->
        []
    end
  end

  def get_gif_captions(_), do: []

  @doc """
  Gets the binary image data for a specific frame with ETS caching.
  """
  def get_frame_image_data(frame_id) do
    # Try cache first
    case NathanForUs.FrameCache.get(frame_id) do
      nil ->
        # Not in cache, get from database
        case Repo.get(VideoFrame, frame_id) do
          %VideoFrame{image_data: image_data} = frame when not is_nil(image_data) ->
            # Cache the frame data for future access
            metadata = %{
              frame_number: frame.frame_number,
              video_id: frame.video_id,
              timestamp_ms: frame.timestamp_ms
            }
            NathanForUs.FrameCache.put(frame_id, image_data, metadata)
            {:ok, image_data}

          %VideoFrame{image_data: nil} ->
            {:error, :no_image_data}

          nil ->
            {:error, :not_found}
        end
      
      cached_data ->
        # Got it from cache
        {:ok, cached_data}
    end
  end

  @doc """
  Gets a sequence of frames around a target frame (target + 5 before and 5 after).
  Returns up to 11 frames total for creating animation sequences.
  """
  def get_frame_sequence(frame_id, sequence_length \\ 5) do
    case Repo.get(VideoFrame, frame_id) do
      %VideoFrame{video_id: video_id, frame_number: target_frame_number} = target_frame ->
        start_frame = max(1, target_frame_number - sequence_length)
        end_frame = target_frame_number + sequence_length

        frames =
          VideoFrame
          |> where([f], f.video_id == ^video_id)
          |> where([f], f.frame_number >= ^start_frame and f.frame_number <= ^end_frame)
          |> order_by([f], f.frame_number)
          |> Repo.all()

        # Get captions for the target frame to provide context
        target_captions =
          from(fc in FrameCaption,
            join: c in VideoCaption,
            on: fc.caption_id == c.id,
            where: fc.frame_id == ^frame_id,
            select: c.text
          )
          |> Repo.all()
          |> Enum.join(" | ")

        # Get captions for all frames in the sequence
        frame_ids = Enum.map(frames, & &1.id)

        sequence_captions =
          from(fc in FrameCaption,
            join: c in VideoCaption,
            on: fc.caption_id == c.id,
            join: f in VideoFrame,
            on: fc.frame_id == f.id,
            where: f.id in ^frame_ids,
            select: %{frame_id: f.id, caption_text: c.text, frame_number: f.frame_number},
            order_by: [f.frame_number, c.start_time_ms]
          )
          |> Repo.all()
          |> Enum.group_by(& &1.frame_id)
          |> Enum.into(%{}, fn {frame_id, captions} ->
            {frame_id, Enum.map(captions, & &1.caption_text)}
          end)

        {:ok,
         %{
           target_frame: target_frame,
           sequence_frames: frames,
           target_captions: target_captions,
           sequence_captions: sequence_captions,
           sequence_info: %{
             target_frame_number: target_frame_number,
             start_frame_number: start_frame,
             end_frame_number: end_frame,
             total_frames: length(frames)
           }
         }}

      nil ->
        {:error, :frame_not_found}
    end
  end

  @doc """
  Gets a sequence of frames around a target frame, ensuring all selected frame indices are covered.
  This variant is used when loading frame sequences from shared URLs with specific frame selections.
  """
  def get_frame_sequence_with_selected_indices(
        frame_id,
        selected_indices,
        base_sequence_length \\ 5
      ) do
    case Repo.get(VideoFrame, frame_id) do
      %VideoFrame{video_id: video_id, frame_number: target_frame_number} = target_frame ->
        # Get video info to check frame count limits
        video = Repo.get(Video, video_id)

        max_frame_number =
          case video.frame_count do
            nil ->
              # Fallback: get the highest frame number for this video
              VideoFrame
              |> where([f], f.video_id == ^video_id)
              |> select([f], max(f.frame_number))
              |> Repo.one() || target_frame_number + base_sequence_length

            count ->
              count
          end

        # Calculate the range needed to cover all selected indices
        {start_frame, end_frame} =
          calculate_range_for_selected_indices(
            target_frame_number,
            selected_indices,
            base_sequence_length,
            max_frame_number
          )

        frames =
          VideoFrame
          |> where([f], f.video_id == ^video_id)
          |> where([f], f.frame_number >= ^start_frame and f.frame_number <= ^end_frame)
          |> order_by([f], f.frame_number)
          |> Repo.all()

        # Get captions for the target frame to provide context
        target_captions =
          from(fc in FrameCaption,
            join: c in VideoCaption,
            on: fc.caption_id == c.id,
            where: fc.frame_id == ^frame_id,
            select: c.text
          )
          |> Repo.all()
          |> Enum.join(" | ")

        # Get captions for all frames in the sequence
        frame_ids = Enum.map(frames, & &1.id)

        sequence_captions =
          from(fc in FrameCaption,
            join: c in VideoCaption,
            on: fc.caption_id == c.id,
            join: f in VideoFrame,
            on: fc.frame_id == f.id,
            where: f.id in ^frame_ids,
            select: %{frame_id: f.id, caption_text: c.text, frame_number: f.frame_number},
            order_by: [f.frame_number, c.start_time_ms]
          )
          |> Repo.all()
          |> Enum.group_by(& &1.frame_id)
          |> Enum.into(%{}, fn {frame_id, captions} ->
            {frame_id, Enum.map(captions, & &1.caption_text)}
          end)

        {:ok,
         %{
           target_frame: target_frame,
           sequence_frames: frames,
           target_captions: target_captions,
           sequence_captions: sequence_captions,
           sequence_info: %{
             target_frame_number: target_frame_number,
             start_frame_number: start_frame,
             end_frame_number: end_frame,
             total_frames: length(frames)
           }
         }}

      nil ->
        {:error, :frame_not_found}
    end
  end

  def get_frame_sequence_from_frame_ids(target_frame_id, frame_ids) do
    case Repo.get(VideoFrame, target_frame_id) do
      %VideoFrame{} = target_frame ->
        # Get all frames by their IDs
        frames =
          VideoFrame
          |> where([f], f.id in ^frame_ids)
          |> order_by([f], f.frame_number)
          |> Repo.all()

        # Get captions for the target frame
        target_captions =
          from(fc in FrameCaption,
            join: c in VideoCaption,
            on: fc.caption_id == c.id,
            where: fc.frame_id == ^target_frame_id,
            select: c.text
          )
          |> Repo.all()
          |> Enum.join(" | ")

        # Get captions for all frames in the sequence
        sequence_captions =
          from(fc in FrameCaption,
            join: c in VideoCaption,
            on: fc.caption_id == c.id,
            join: f in VideoFrame,
            on: fc.frame_id == f.id,
            where: f.id in ^frame_ids,
            select: %{frame_id: f.id, caption_text: c.text, frame_number: f.frame_number},
            order_by: [f.frame_number, c.start_time_ms]
          )
          |> Repo.all()
          |> Enum.group_by(& &1.frame_id)
          |> Enum.into(%{}, fn {frame_id, captions} ->
            {frame_id, Enum.map(captions, & &1.caption_text)}
          end)

        {:ok,
         %{
           target_frame: target_frame,
           sequence_frames: frames,
           target_captions: target_captions,
           sequence_captions: sequence_captions,
           sequence_info: %{
             target_frame_number: target_frame.frame_number,
             start_frame_number: frames |> Enum.map(& &1.frame_number) |> Enum.min(),
             end_frame_number: frames |> Enum.map(& &1.frame_number) |> Enum.max(),
             total_frames: length(frames)
           }
         }}

      nil ->
        {:error, :frame_not_found}
    end
  end

  # Private helper to calculate the frame range needed to cover selected indices
  defp calculate_range_for_selected_indices(
         target_frame_number,
         selected_indices,
         base_sequence_length,
         max_frame_number
       ) do
    if Enum.empty?(selected_indices) do
      # No selected indices, use default range
      start_frame = max(1, target_frame_number - base_sequence_length)
      end_frame = target_frame_number + base_sequence_length
      # Limit end_frame to max available frame if specified
      end_frame = if max_frame_number, do: min(end_frame, max_frame_number), else: end_frame
      {start_frame, end_frame}
    else
      # Calculate the range based on default sequence and selected indices
      default_start = max(1, target_frame_number - base_sequence_length)
      default_end = target_frame_number + base_sequence_length

      # Convert selected indices to actual frame numbers
      # Assuming the sequence starts at default_start, selected indices map to:
      # index 0 -> default_start, index 1 -> default_start + 1, etc.
      min_selected_index = Enum.min(selected_indices)
      max_selected_index = Enum.max(selected_indices)

      # Calculate the actual frame numbers for the selected indices
      min_selected_frame = default_start + min_selected_index
      max_selected_frame = default_start + max_selected_index

      # Expand the range to ensure we cover all selected frames
      start_frame = max(1, min(default_start, min_selected_frame))
      end_frame = max(default_end, max_selected_frame)

      # Limit end_frame to max available frame if specified
      end_frame = if max_frame_number, do: min(end_frame, max_frame_number), else: end_frame

      {start_frame, end_frame}
    end
  end

  @doc """
  Expands frame sequence backward by adding the previous frame.
  """
  def expand_frame_sequence_backward(frame_sequence) do
    %{target_frame: target_frame, sequence_frames: current_frames, sequence_info: info} =
      frame_sequence

    video_id = target_frame.video_id
    current_start = info.start_frame_number

    # Can we go back one more frame?
    if current_start > 1 do
      new_start = current_start - 1

      # Get the additional frame
      additional_frame =
        VideoFrame
        |> where([f], f.video_id == ^video_id and f.frame_number == ^new_start)
        |> Repo.one()

      case additional_frame do
        %VideoFrame{} = frame ->
          # Add the new frame to the beginning of the sequence
          new_frames = [frame | current_frames]

          # Get captions for the new frame
          new_frame_captions =
            from(fc in FrameCaption,
              join: c in VideoCaption,
              on: fc.caption_id == c.id,
              where: fc.frame_id == ^frame.id,
              select: c.text
            )
            |> Repo.all()

          # Update sequence captions
          updated_sequence_captions =
            Map.put(frame_sequence.sequence_captions, frame.id, new_frame_captions)

          # Update sequence info
          updated_info = %{info | start_frame_number: new_start, total_frames: length(new_frames)}

          {:ok,
           %{
             frame_sequence
             | sequence_frames: new_frames,
               sequence_captions: updated_sequence_captions,
               sequence_info: updated_info
           }}

        nil ->
          {:error, :frame_not_found}
      end
    else
      {:error, :at_beginning}
    end
  end

  @doc """
  Expands frame sequence forward by adding the next frame.
  """
  def expand_frame_sequence_forward(frame_sequence) do
    %{target_frame: target_frame, sequence_frames: current_frames, sequence_info: info} =
      frame_sequence

    video_id = target_frame.video_id
    current_end = info.end_frame_number

    # Get the video to check max frame count
    video = Repo.get(Video, video_id)

    max_frame_number =
      case video.frame_count do
        nil ->
          # Fallback: get the highest frame number for this video
          VideoFrame
          |> where([f], f.video_id == ^video_id)
          |> select([f], max(f.frame_number))
          |> Repo.one() || current_end

        count ->
          count
      end

    # Can we go forward one more frame?
    if current_end < max_frame_number do
      new_end = current_end + 1

      # Get the additional frame
      additional_frame =
        VideoFrame
        |> where([f], f.video_id == ^video_id and f.frame_number == ^new_end)
        |> Repo.one()

      case additional_frame do
        %VideoFrame{} = frame ->
          # Add the new frame to the end of the sequence
          new_frames = current_frames ++ [frame]

          # Get captions for the new frame
          new_frame_captions =
            from(fc in FrameCaption,
              join: c in VideoCaption,
              on: fc.caption_id == c.id,
              where: fc.frame_id == ^frame.id,
              select: c.text
            )
            |> Repo.all()

          # Update sequence captions
          updated_sequence_captions =
            Map.put(frame_sequence.sequence_captions, frame.id, new_frame_captions)

          # Update sequence info
          updated_info = %{info | end_frame_number: new_end, total_frames: length(new_frames)}

          {:ok,
           %{
             frame_sequence
             | sequence_frames: new_frames,
               sequence_captions: updated_sequence_captions,
               sequence_info: updated_info
           }}

        nil ->
          {:error, :frame_not_found}
      end
    else
      {:error, :at_end}
    end
  end

  @doc """
  Gets captions for a list of frame IDs.
  Returns a map of frame_id => [caption_texts].
  """
  def get_frames_captions(frame_ids) when is_list(frame_ids) do
    if length(frame_ids) == 0 do
      {:ok, %{}}
    else
      captions_map =
        from(fc in FrameCaption,
          join: c in VideoCaption,
          on: fc.caption_id == c.id,
          where: fc.frame_id in ^frame_ids,
          select: %{frame_id: fc.frame_id, caption_text: c.text},
          order_by: [fc.frame_id, c.start_time_ms]
        )
        |> Repo.all()
        |> Enum.group_by(& &1.frame_id)
        |> Enum.into(%{}, fn {frame_id, captions} ->
          {frame_id, Enum.map(captions, & &1.caption_text)}
        end)

      {:ok, captions_map}
    end
  end

  @doc """
  Gets autocomplete suggestions for search phrases based on video captions.
  Returns full caption phrases that contain the given term.
  """
  def get_autocomplete_suggestions(search_term, video_ids \\ nil, limit \\ 5)
      when is_binary(search_term) do
    if String.length(search_term) < 3 do
      []
    else
      search_pattern = "%#{search_term}%"

      # Query with optional video ID filtering
      {query, params} =
        case video_ids do
          nil ->
            # Global search across all videos
            query = """
            SELECT text FROM (
              SELECT DISTINCT text, length(text) as text_length 
              FROM video_captions 
              WHERE text ILIKE $1
            ) sub 
            ORDER BY text_length 
            LIMIT $2
            """

            {query, [search_pattern, limit]}

          video_id when is_integer(video_id) ->
            # Search within specific video
            query = """
            SELECT text FROM (
              SELECT DISTINCT text, length(text) as text_length 
              FROM video_captions vc
              JOIN video_frames vf ON vc.video_frame_id = vf.id
              WHERE vf.video_id = $1 AND vc.text ILIKE $2
            ) sub 
            ORDER BY text_length 
            LIMIT $3
            """

            {query, [video_id, search_pattern, limit]}

          video_ids when is_list(video_ids) ->
            # Search within multiple videos
            placeholders = Enum.map_join(1..length(video_ids), ", ", &"$#{&1}")

            query = """
            SELECT text FROM (
              SELECT DISTINCT text, length(text) as text_length 
              FROM video_captions vc
              JOIN video_frames vf ON vc.video_frame_id = vf.id
              WHERE vf.video_id IN (#{placeholders}) AND vc.text ILIKE $#{length(video_ids) + 1}
            ) sub 
            ORDER BY text_length 
            LIMIT $#{length(video_ids) + 2}
            """

            {query, video_ids ++ [search_pattern, limit]}
        end

      case Ecto.Adapters.SQL.query(Repo, query, params) do
        {:ok, %{rows: rows}} ->
          rows
          |> List.flatten()
          |> Enum.map(&String.trim/1)
          # Filter out very short phrases
          |> Enum.reject(&(String.length(&1) < 5))
          |> Enum.uniq()
          |> Enum.take(limit)

        {:error, reason} ->
          require Logger
          Logger.warning("Autocomplete query failed: #{inspect(reason)}")
          []
      end
    end
  end

  @doc """
  Gets sample caption suggestions to inspire user searches.
  Returns interesting random caption phrases to display when search box is empty.
  """
  def get_sample_caption_suggestions(limit \\ 6) do
    query = """
    SELECT text FROM (
      SELECT DISTINCT text, length(text) as text_length,
        CASE 
          WHEN text ILIKE '%business%' THEN 1
          WHEN text ILIKE '%rehearsal%' THEN 1
          WHEN text ILIKE '%plan%' THEN 1
          WHEN text ILIKE '%strategy%' THEN 1
          WHEN text ILIKE '%prepared%' THEN 1
          WHEN text ILIKE '%nathan%' THEN 1
          ELSE 2
        END as priority
      FROM video_captions 
      WHERE text IS NOT NULL 
        AND length(text) BETWEEN 10 AND 80
        AND text NOT ILIKE '%[%'
        AND text NOT ILIKE '%]%'
        AND text NOT ILIKE '%♪%'
        AND text NOT ILIKE '%music%'
    ) sub 
    ORDER BY priority, RANDOM()
    LIMIT $1
    """

    case Ecto.Adapters.SQL.query(Repo, query, [limit]) do
      {:ok, %{rows: rows}} ->
        rows
        |> List.flatten()
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(String.length(&1) < 5))
        |> Enum.uniq()

      {:error, reason} ->
        require Logger
        Logger.warning("Sample caption suggestions query failed: #{inspect(reason)}")
        # Fallback suggestions
        [
          "I graduated from one of Canada's top business schools",
          "The plan is working perfectly",
          "I've been rehearsing for this moment",
          "This is a business strategy",
          "I'm prepared for anything",
          "Let's get down to business"
        ]
    end
  end

  @doc """
  Migrates existing frames from file paths to binary storage with compression.
  """
  def migrate_frames_to_binary(video_id, jpeg_quality \\ 75) do
    frames =
      VideoFrame
      |> where([f], f.video_id == ^video_id)
      # Only migrate frames without binary data
      |> where([f], is_nil(f.image_data))
      # Only frames with file paths
      |> where([f], not is_nil(f.file_path))
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

            # Count successful migration
            1

          {:error, reason} ->
            require Logger
            Logger.warning("Failed to compress frame #{frame.id}: #{inspect(reason)}")
            # Count failed migration
            0
        end
      end)
      |> Enum.sum()

    {:ok, migrated_count}
  end

  @doc """
  Gets the total frame count for a video.
  """
  def get_video_frame_count(video_id) do
    count =
      VideoFrame
      |> where([f], f.video_id == ^video_id)
      |> select([f], count(f.id))
      |> Repo.one()

    case count do
      nil -> {:ok, 0}
      count when count > 0 -> {:ok, count}
      _ -> {:ok, 0}
    end
  end

  @doc """
  Gets the video duration in milliseconds based on the last frame timestamp.
  """
  def get_video_duration_ms(video_id) do
    VideoFrame
    |> where([f], f.video_id == ^video_id)
    |> select([f], max(f.timestamp_ms))
    |> Repo.one()
  end

  @doc """
  Gets video frames within a specific frame number range.
  """
  def get_video_frames_in_range(video_id, start_frame, end_frame) do
    VideoFrame
    |> where([f], f.video_id == ^video_id)
    |> where([f], f.frame_number >= ^start_frame and f.frame_number <= ^end_frame)
    |> order_by([f], f.frame_number)
    |> Repo.all()
  end

  @doc """
  Gets video frames that contain specific caption text, ordered by frame number.
  Returns frames with matching captions for timeline filtering.
  """
  def get_video_frames_with_caption_text(video_id, search_term) when is_binary(search_term) do
    if String.length(search_term) < 3 do
      []
    else
      search_pattern = "%#{search_term}%"

      query = """
      SELECT DISTINCT f.*, 
             string_agg(DISTINCT c.text, ' | ') as caption_texts
      FROM video_frames f
      JOIN frame_captions fc ON fc.frame_id = f.id
      JOIN video_captions c ON c.id = fc.caption_id
      WHERE f.video_id = $1 AND c.text ILIKE $2
      GROUP BY f.id, f.video_id, f.frame_number, f.timestamp_ms, f.file_path, f.file_size, f.width, f.height, f.image_data, f.compression_ratio, f.inserted_at, f.updated_at
      ORDER BY f.frame_number
      """

      case Ecto.Adapters.SQL.query(Repo, query, [video_id, search_pattern]) do
        {:ok, %{rows: rows, columns: columns}} ->
          rows
          |> Enum.map(fn row ->
            # Convert the row data back to a VideoFrame struct
            frame_data = Enum.zip(columns, row) |> Enum.into(%{})

            %VideoFrame{
              id: frame_data["id"],
              video_id: frame_data["video_id"],
              frame_number: frame_data["frame_number"],
              timestamp_ms: frame_data["timestamp_ms"],
              file_path: frame_data["file_path"],
              file_size: frame_data["file_size"],
              width: frame_data["width"],
              height: frame_data["height"],
              image_data: frame_data["image_data"],
              compression_ratio: frame_data["compression_ratio"],
              inserted_at: frame_data["inserted_at"],
              updated_at: frame_data["updated_at"]
            }
            |> Map.put(:caption_texts, frame_data["caption_texts"])
          end)

        {:error, reason} ->
          require Logger
          Logger.warning("Caption search query failed: #{inspect(reason)}")
          []
      end
    end
  end

  @doc """
  Gets captions for a specific frame.
  Returns a list of caption texts associated with the frame.
  """
  def get_frame_captions(frame_id) do
    query = """
    SELECT c.text
    FROM video_captions c
    JOIN frame_captions fc ON fc.caption_id = c.id
    WHERE fc.frame_id = $1
    ORDER BY c.start_time_ms
    """

    case Ecto.Adapters.SQL.query(Repo, query, [frame_id]) do
      {:ok, %{rows: rows}} ->
        rows |> List.flatten()

      {:error, reason} ->
        require Logger
        Logger.warning("Frame captions query failed: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Gets frames with context around a specific frame.
  Returns frames from (frame_number - context_before) to (frame_number + context_after).
  Includes metadata about which frame was the original search result.
  """
  def get_frames_with_context(
        video_id,
        target_frame_number,
        context_before \\ 5,
        context_after \\ 5
      ) do
    start_frame = max(0, target_frame_number - context_before)
    end_frame = target_frame_number + context_after

    frames =
      VideoFrame
      |> where([f], f.video_id == ^video_id)
      |> where([f], f.frame_number >= ^start_frame and f.frame_number <= ^end_frame)
      |> order_by([f], f.frame_number)
      |> Repo.all()

    # Add metadata to indicate which frame was the target
    frames
    |> Enum.map(fn frame ->
      frame
      |> Map.put(:is_target_frame, frame.frame_number == target_frame_number)
      |> Map.put(
        :context_type,
        cond do
          frame.frame_number < target_frame_number -> :before
          frame.frame_number > target_frame_number -> :after
          true -> :target
        end
      )
    end)
  end

  @doc """
  Expands existing context frames by adding more frames to the left (before).
  Takes current context frames and adds N more frames before the earliest frame.
  """
  def expand_context_left(video_id, current_frames, target_frame_number, expand_count) do
    return_empty = fn -> current_frames end

    case current_frames do
      [] ->
        return_empty.()

      frames ->
        # Find the earliest frame number in current context
        earliest_frame_number = frames |> Enum.map(& &1.frame_number) |> Enum.min()

        # Calculate new start frame (expand_count frames before the earliest)
        new_start_frame = max(0, earliest_frame_number - expand_count)

        # If we can't expand (already at frame 0), return current frames
        if new_start_frame >= earliest_frame_number do
          return_empty.()
        else
          # Get the additional frames
          additional_frames =
            VideoFrame
            |> where([f], f.video_id == ^video_id)
            |> where(
              [f],
              f.frame_number >= ^new_start_frame and f.frame_number < ^earliest_frame_number
            )
            |> order_by([f], f.frame_number)
            |> Repo.all()

          # Add metadata to new frames
          additional_with_metadata =
            additional_frames
            |> Enum.map(fn frame ->
              frame
              |> Map.put(:is_target_frame, frame.frame_number == target_frame_number)
              |> Map.put(
                :context_type,
                cond do
                  frame.frame_number < target_frame_number -> :before
                  frame.frame_number > target_frame_number -> :after
                  true -> :target
                end
              )
            end)

          # Combine with existing frames
          additional_with_metadata ++ current_frames
        end
    end
  end

  @doc """
  Expands existing context frames by adding more frames to the right (after).
  Takes current context frames and adds N more frames after the latest frame.
  """
  def expand_context_right(video_id, current_frames, target_frame_number, expand_count) do
    return_empty = fn -> current_frames end

    case current_frames do
      [] ->
        return_empty.()

      frames ->
        # Find the latest frame number in current context
        latest_frame_number = frames |> Enum.map(& &1.frame_number) |> Enum.max()

        # Calculate new end frame (expand_count frames after the latest)
        new_end_frame = latest_frame_number + expand_count

        # Get the additional frames
        additional_frames =
          VideoFrame
          |> where([f], f.video_id == ^video_id)
          |> where(
            [f],
            f.frame_number > ^latest_frame_number and f.frame_number <= ^new_end_frame
          )
          |> order_by([f], f.frame_number)
          |> Repo.all()

        # If no additional frames found, return current frames
        if Enum.empty?(additional_frames) do
          return_empty.()
        else
          # Add metadata to new frames
          additional_with_metadata =
            additional_frames
            |> Enum.map(fn frame ->
              frame
              |> Map.put(:is_target_frame, frame.frame_number == target_frame_number)
              |> Map.put(
                :context_type,
                cond do
                  frame.frame_number < target_frame_number -> :before
                  frame.frame_number > target_frame_number -> :after
                  true -> :target
                end
              )
            end)

          # Combine with existing frames
          current_frames ++ additional_with_metadata
        end
    end
  end

  @doc """
  Gets a frame sequence starting from a specific frame number.
  This is used for generating random clips.
  """
  def get_frame_sequence_by_frame_number(video_id, frame_number, sequence_length \\ 5) do
    # Find the frame at the specified frame number
    target_frame =
      VideoFrame
      |> where([f], f.video_id == ^video_id and f.frame_number == ^frame_number)
      |> Repo.one()

    case target_frame do
      %VideoFrame{} = frame ->
        # Use the existing get_frame_sequence function
        get_frame_sequence(frame.id, sequence_length)

      nil ->
        {:error, :frame_not_found}
    end
  end

  @doc """
  Gets a random video with a random sequence of frames for GIF creation.
  Returns {:ok, video_id, start_frame_number} or {:error, reason}.
  """
  def get_random_video_sequence(sequence_length \\ 15) do
    # Get a random video that has frames
    video_query = """
    SELECT v.id, COUNT(f.id) as frame_count
    FROM videos v
    JOIN video_frames f ON f.video_id = v.id
    WHERE v.id != 14
    GROUP BY v.id
    HAVING COUNT(f.id) >= $1
    ORDER BY RANDOM()
    LIMIT 1
    """

    case Ecto.Adapters.SQL.query(Repo, video_query, [sequence_length]) do
      {:ok, %{rows: [[video_id, frame_count]]}} ->
        # Pick a random starting frame that allows for the full sequence
        max_start_frame = max(1, frame_count - sequence_length + 1)
        start_frame = :rand.uniform(max_start_frame)

        {:ok, video_id, start_frame}

      {:ok, %{rows: []}} ->
        {:error, :no_suitable_videos}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets random frames from all videos for background slideshow.
  Returns a list of frames with video information.
  """
  def get_random_frames(count \\ 50) do
    # Get a sample of random frames from all videos except video ID 14
    query = """
    SELECT f.id, f.video_id, f.frame_number, f.timestamp_ms, f.image_data, f.width, f.height,
           v.title as video_title, v.file_path as video_file_path
    FROM video_frames f
    JOIN videos v ON f.video_id = v.id
    WHERE f.video_id != 14
    ORDER BY RANDOM()
    LIMIT $1
    """

    case Ecto.Adapters.SQL.query(Repo, query, [count]) do
      {:ok, %{rows: rows, columns: columns}} ->
        Enum.map(rows, fn row ->
          columns
          |> Enum.zip(row)
          |> Enum.into(%{})
          |> Map.update!("image_data", fn data ->
            case data do
              nil -> nil
              binary_data -> Base.encode64(binary_data)
            end
          end)
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Counts the number of frames for a video.
  """
  def count_video_frames(video_id) do
    VideoFrame
    |> where([f], f.video_id == ^video_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts the number of captions for a video.
  """
  def count_video_captions(video_id) do
    VideoCaption
    |> where([c], c.video_id == ^video_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts the number of frame-caption links for a video.
  """
  def count_frame_caption_links(video_id) do
    query =
      from fc in FrameCaption,
        join: f in VideoFrame,
        on: fc.frame_id == f.id,
        where: f.video_id == ^video_id,
        select: count(fc.id)

    Repo.one(query)
  end
end
