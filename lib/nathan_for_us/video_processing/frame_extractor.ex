defmodule NathanForUs.VideoProcessing.FrameExtractor do
  @moduledoc """
  GenStage producer-consumer for video frame extraction.
  
  This stage receives video records from the Producer and performs frame extraction
  using ffmpeg through the VideoProcessor module. It handles:
  
  - Frame extraction with configurable quality and frame rate
  - Video metadata retrieval (duration, frame count)
  - Error handling with proper video status updates
  - Efficient processing with hardware acceleration when available
  
  ## Pipeline Position
  
      Producer -> FrameExtractor -> CaptionParser -> DatabaseConsumer
      
  ## Processing Flow
  
  1. Receives video records from Producer
  2. Extracts frames using VideoProcessor
  3. Retrieves video metadata (duration, etc.)
  4. Updates video record with metadata
  5. Emits processed events with frame data
  6. Handles errors by marking videos as failed
  
  ## Configuration
  
  Frame extraction uses these defaults:
  - FPS: 1 (one frame per second)
  - Quality: 3 (good quality, reasonable file size)
  - Hardware acceleration: enabled (VideoToolbox on macOS)
  """
  
  use GenStage
  require Logger
  
  alias NathanForUs.{VideoProcessor, Video, Errors}

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Frame extractor starting")
    
    {:producer_consumer, %{},
     subscribe_to: [
       {NathanForUs.VideoProcessing.Producer, min_demand: 1, max_demand: 3}
     ]}
  end

  @impl true
  def handle_events(videos, _from, state) do
    Logger.info("Frame extractor received #{length(videos)} videos")
    
    events = 
      videos
      |> Enum.map(&process_video/1)
      |> Enum.reject(&is_nil/1)
    
    {:noreply, events, state}
  end

  defp process_video(%Video.Video{} = video) do
    Logger.info("Processing video: #{video.title}")
    
    with {:ok, frame_paths} <- extract_frames(video),
         {:ok, video_metadata} <- get_video_metadata(video),
         {:ok, _updated_video} <- update_video_metadata(video, video_metadata, frame_paths) do
      
      frame_data = build_frame_data(frame_paths, video_metadata.duration_ms)
      
      %{
        video: video,
        frame_data: frame_data,
        frame_paths: frame_paths
      }
    else
      {:error, reason} ->
        error = Errors.VideoProcessingError.exception(
          video_path: video.file_path,
          stage: "frame_extraction",
          reason: reason
        )
        
        Errors.log_error("Frame extraction failed", error, video_id: video.id, video_title: video.title)
        mark_video_failed(video)
        nil
    end
  end

  defp extract_frames(%Video.Video{} = video) do
    output_dir = build_output_dir(video)
    processor = build_frame_processor(video, output_dir)
    
    case VideoProcessor.extract_frames(processor) do
      {:ok, frame_paths} ->
        Logger.info("Extracted #{length(frame_paths)} frames from #{video.title}")
        {:ok, frame_paths}
      
      {:error, reason} ->
        {:error, "Frame extraction failed: #{reason}"}
    end
  end

  defp get_video_metadata(%Video.Video{} = video) do
    case VideoProcessor.get_video_info(video.file_path) do
      {:ok, video_info} ->
        duration_ms = extract_duration_ms(video_info)
        {:ok, %{duration_ms: duration_ms, video_info: video_info}}
      
      {:error, reason} ->
        {:error, "Failed to get video metadata: #{reason}"}
    end
  end

  defp update_video_metadata(video, metadata, frame_paths) do
    Video.update_video(video, %{
      duration_ms: metadata.duration_ms,
      frame_count: length(frame_paths)
    })
  end

  defp mark_video_failed(video) do
    Video.update_video(video, %{
      status: "failed",
      completed_at: DateTime.utc_now()
    })
  end

  defp build_output_dir(%Video.Video{id: id}) do
    Path.join("priv/static/frames", "video_#{id}")
  end

  defp build_frame_processor(%Video.Video{file_path: file_path}, output_dir) do
    VideoProcessor.new(file_path,
      output_dir: output_dir,
      fps: 1,
      quality: 3,
      use_hardware_accel: true
    )
  end

  defp build_frame_data(frame_paths, duration_ms) do
    total_frames = length(frame_paths)
    
    frame_paths
    |> Enum.with_index()
    |> Enum.map(fn {frame_path, index} ->
      %{
        frame_number: index,
        timestamp_ms: calculate_timestamp(index, total_frames, duration_ms),
        file_path: frame_path,
        file_size: get_file_size(frame_path)
      }
    end)
  end

  defp calculate_timestamp(index, total_frames, duration_ms) do
    if duration_ms && total_frames > 1 do
      trunc((index / (total_frames - 1)) * duration_ms)
    else
      index * 1000
    end
  end

  defp get_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %File.Stat{size: size}} -> size
      {:error, _} -> 0
    end
  end

  defp extract_duration_ms(%{"format" => %{"duration" => duration_str}}) do
    case Float.parse(duration_str) do
      {duration_seconds, _} -> trunc(duration_seconds * 1000)
      :error -> nil
    end
  end
  defp extract_duration_ms(_), do: nil

end