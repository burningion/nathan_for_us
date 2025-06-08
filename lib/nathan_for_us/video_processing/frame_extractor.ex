defmodule NathanForUs.VideoProcessing.FrameExtractor do
  @moduledoc """
  GenStage producer-consumer that extracts frames from videos using ffmpeg.
  
  Takes video records from the producer, extracts frames, and emits
  events containing both the video and the extracted frame data.
  """
  
  use GenStage
  require Logger
  
  alias NathanForUs.{VideoProcessor, Video}

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
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
      |> Enum.map(&extract_frames_from_video/1)
      |> Enum.reject(&is_nil/1)
    
    {:noreply, events, state}
  end

  defp extract_frames_from_video(%Video.Video{} = video) do
    Logger.info("Extracting frames from video: #{video.title}")
    
    # Create output directory for this video
    output_dir = Path.join("priv/static/frames", "video_#{video.id}")
    
    # Configure frame extraction
    processor = VideoProcessor.new(video.file_path,
      output_dir: output_dir,
      fps: 1,  # Extract 1 frame per second
      quality: 3,  # Good quality but not too large
      use_hardware_accel: true
    )
    
    case VideoProcessor.extract_frames(processor) do
      {:ok, frame_paths} ->
        Logger.info("Extracted #{length(frame_paths)} frames from #{video.title}")
        
        # Get video metadata
        {:ok, video_info} = VideoProcessor.get_video_info(video.file_path)
        duration_ms = extract_duration_ms(video_info)
        
        # Update video with metadata
        Video.update_video(video, %{
          duration_ms: duration_ms,
          frame_count: length(frame_paths)
        })
        
        # Create frame data for database insertion
        frame_data = create_frame_data(frame_paths, duration_ms)
        
        %{
          video: video,
          frame_data: frame_data,
          frame_paths: frame_paths
        }
        
      {:error, reason} ->
        Logger.error("Failed to extract frames from #{video.title}: #{reason}")
        
        Video.update_video(video, %{
          status: "failed",
          completed_at: DateTime.utc_now()
        })
        
        nil
    end
  end

  defp extract_duration_ms(%{"format" => %{"duration" => duration_str}}) do
    case Float.parse(duration_str) do
      {duration_seconds, _} -> trunc(duration_seconds * 1000)
      :error -> nil
    end
  end
  defp extract_duration_ms(_), do: nil

  defp create_frame_data(frame_paths, duration_ms) do
    total_frames = length(frame_paths)
    
    frame_paths
    |> Enum.with_index()
    |> Enum.map(fn {frame_path, index} ->
      # Calculate timestamp based on frame position
      timestamp_ms = if duration_ms && total_frames > 1 do
        trunc((index / (total_frames - 1)) * duration_ms)
      else
        index * 1000  # Fallback: 1 second intervals
      end
      
      # Get file info
      file_stats = File.stat!(frame_path)
      
      %{
        frame_number: index,
        timestamp_ms: timestamp_ms,
        file_path: frame_path,
        file_size: file_stats.size
      }
    end)
  end
end