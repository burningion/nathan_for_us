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
  def search_frames_by_text_simple_filtered(search_term, video_ids) when is_binary(search_term) and is_list(video_ids) do
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
  def search_frames_by_text_simple(search_term, video_id) when is_binary(search_term) and is_integer(video_id) do
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
  Gets a sequence of frames around a target frame (target + 5 before and 5 after).
  Returns up to 11 frames total for creating animation sequences.
  """
  def get_frame_sequence(frame_id, sequence_length \\ 5) do
    case Repo.get(VideoFrame, frame_id) do
      %VideoFrame{video_id: video_id, frame_number: target_frame_number} = target_frame ->
        start_frame = max(1, target_frame_number - sequence_length)
        end_frame = target_frame_number + sequence_length
        
        frames = VideoFrame
        |> where([f], f.video_id == ^video_id)
        |> where([f], f.frame_number >= ^start_frame and f.frame_number <= ^end_frame)
        |> order_by([f], f.frame_number)
        |> Repo.all()
        
        # Get captions for the target frame to provide context
        target_captions = from(fc in FrameCaption,
          join: c in VideoCaption, on: fc.caption_id == c.id,
          where: fc.frame_id == ^frame_id,
          select: c.text
        )
        |> Repo.all()
        |> Enum.join(" | ")
        
        # Get captions for all frames in the sequence
        frame_ids = Enum.map(frames, & &1.id)
        sequence_captions = from(fc in FrameCaption,
          join: c in VideoCaption, on: fc.caption_id == c.id,
          join: f in VideoFrame, on: fc.frame_id == f.id,
          where: f.id in ^frame_ids,
          select: %{frame_id: f.id, caption_text: c.text, frame_number: f.frame_number},
          order_by: [f.frame_number, c.start_time_ms]
        )
        |> Repo.all()
        |> Enum.group_by(& &1.frame_id)
        |> Enum.into(%{}, fn {frame_id, captions} ->
          {frame_id, Enum.map(captions, & &1.caption_text)}
        end)
        
        {:ok, %{
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
  def get_frame_sequence_with_selected_indices(frame_id, selected_indices, base_sequence_length \\ 5) do
    case Repo.get(VideoFrame, frame_id) do
      %VideoFrame{video_id: video_id, frame_number: target_frame_number} = target_frame ->
        # Get video info to check frame count limits
        video = Repo.get(Video, video_id)
        max_frame_number = case video.frame_count do
          nil -> 
            # Fallback: get the highest frame number for this video
            VideoFrame
            |> where([f], f.video_id == ^video_id)
            |> select([f], max(f.frame_number))
            |> Repo.one() || target_frame_number + base_sequence_length
          count -> count
        end
        
        # Calculate the range needed to cover all selected indices
        {start_frame, end_frame} = calculate_range_for_selected_indices(
          target_frame_number, 
          selected_indices, 
          base_sequence_length,
          max_frame_number
        )
        
        frames = VideoFrame
        |> where([f], f.video_id == ^video_id)
        |> where([f], f.frame_number >= ^start_frame and f.frame_number <= ^end_frame)
        |> order_by([f], f.frame_number)
        |> Repo.all()
        
        # Get captions for the target frame to provide context
        target_captions = from(fc in FrameCaption,
          join: c in VideoCaption, on: fc.caption_id == c.id,
          where: fc.frame_id == ^frame_id,
          select: c.text
        )
        |> Repo.all()
        |> Enum.join(" | ")
        
        # Get captions for all frames in the sequence
        frame_ids = Enum.map(frames, & &1.id)
        sequence_captions = from(fc in FrameCaption,
          join: c in VideoCaption, on: fc.caption_id == c.id,
          join: f in VideoFrame, on: fc.frame_id == f.id,
          where: f.id in ^frame_ids,
          select: %{frame_id: f.id, caption_text: c.text, frame_number: f.frame_number},
          order_by: [f.frame_number, c.start_time_ms]
        )
        |> Repo.all()
        |> Enum.group_by(& &1.frame_id)
        |> Enum.into(%{}, fn {frame_id, captions} ->
          {frame_id, Enum.map(captions, & &1.caption_text)}
        end)
        
        {:ok, %{
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

  # Private helper to calculate the frame range needed to cover selected indices
  defp calculate_range_for_selected_indices(target_frame_number, selected_indices, base_sequence_length, max_frame_number) do
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
    %{target_frame: target_frame, sequence_frames: current_frames, sequence_info: info} = frame_sequence
    video_id = target_frame.video_id
    current_start = info.start_frame_number
    
    # Can we go back one more frame?
    if current_start > 1 do
      new_start = current_start - 1
      
      # Get the additional frame
      additional_frame = VideoFrame
      |> where([f], f.video_id == ^video_id and f.frame_number == ^new_start)
      |> Repo.one()
      
      case additional_frame do
        %VideoFrame{} = frame ->
          # Add the new frame to the beginning of the sequence
          new_frames = [frame | current_frames]
          
          # Get captions for the new frame
          new_frame_captions = from(fc in FrameCaption,
            join: c in VideoCaption, on: fc.caption_id == c.id,
            where: fc.frame_id == ^frame.id,
            select: c.text
          )
          |> Repo.all()
          
          # Update sequence captions
          updated_sequence_captions = Map.put(frame_sequence.sequence_captions, frame.id, new_frame_captions)
          
          # Update sequence info
          updated_info = %{info | 
            start_frame_number: new_start,
            total_frames: length(new_frames)
          }
          
          {:ok, %{frame_sequence | 
            sequence_frames: new_frames,
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
    %{target_frame: target_frame, sequence_frames: current_frames, sequence_info: info} = frame_sequence
    video_id = target_frame.video_id
    current_end = info.end_frame_number
    
    # Get the video to check max frame count
    video = Repo.get(Video, video_id)
    max_frame_number = case video.frame_count do
      nil -> 
        # Fallback: get the highest frame number for this video
        VideoFrame
        |> where([f], f.video_id == ^video_id)
        |> select([f], max(f.frame_number))
        |> Repo.one() || current_end
      count -> count
    end
    
    # Can we go forward one more frame?
    if current_end < max_frame_number do
      new_end = current_end + 1
      
      # Get the additional frame
      additional_frame = VideoFrame
      |> where([f], f.video_id == ^video_id and f.frame_number == ^new_end)
      |> Repo.one()
      
      case additional_frame do
        %VideoFrame{} = frame ->
          # Add the new frame to the end of the sequence
          new_frames = current_frames ++ [frame]
          
          # Get captions for the new frame
          new_frame_captions = from(fc in FrameCaption,
            join: c in VideoCaption, on: fc.caption_id == c.id,
            where: fc.frame_id == ^frame.id,
            select: c.text
          )
          |> Repo.all()
          
          # Update sequence captions
          updated_sequence_captions = Map.put(frame_sequence.sequence_captions, frame.id, new_frame_captions)
          
          # Update sequence info
          updated_info = %{info | 
            end_frame_number: new_end,
            total_frames: length(new_frames)
          }
          
          {:ok, %{frame_sequence | 
            sequence_frames: new_frames,
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
  Gets autocomplete suggestions for search phrases based on video captions.
  Returns full caption phrases that contain the given term.
  """
  def get_autocomplete_suggestions(search_term, _video_ids \\ nil, limit \\ 5) when is_binary(search_term) do
    if String.length(search_term) < 3 do
      []
    else
      search_pattern = "%#{search_term}%"
      
      # Fixed query: SELECT DISTINCT with ORDER BY in subquery
      query = """
      SELECT text FROM (
        SELECT DISTINCT text, length(text) as text_length 
        FROM video_captions 
        WHERE text ILIKE $1
      ) sub 
      ORDER BY text_length 
      LIMIT $2
      """
      
      case Ecto.Adapters.SQL.query(Repo, query, [search_pattern, limit]) do
        {:ok, %{rows: rows}} ->
          rows
          |> List.flatten()
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(String.length(&1) < 5))  # Filter out very short phrases
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