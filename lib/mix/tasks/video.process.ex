defmodule Mix.Tasks.Video.Process do
  @moduledoc """
  Simple video processor that extracts frames, parses captions, and stores everything in the database.
  
  Usage:
    mix video.process --video-path="/path/to/video.mp4" --title="Video Title"
    mix video.process --video-path="/path/to/video.mp4" --title="Video Title" --captions-path="/path/to/captions.srt"
  """
  
  use Mix.Task
  require Logger
  
  alias NathanForUs.{Video, VideoProcessor, SrtParser, Repo}
  alias NathanForUs.Video.{VideoFrame, VideoCaption}
  
  @shortdoc "Process video: extract frames, parse captions, store in database"
  
  def run(args) do
    {opts, _} = OptionParser.parse!(args, 
      strict: [
        video_path: :string,
        title: :string,
        captions_path: :string,
        fps: :float,
        quality: :integer
      ]
    )
    
    video_path = opts[:video_path] || raise "Missing required --video-path"
    title = opts[:title] || Path.basename(video_path, Path.extname(video_path))
    captions_path = opts[:captions_path] || find_caption_file(video_path)
    fps = opts[:fps] || 1.0
    quality = opts[:quality] || 3
    
    Logger.info("🎬 Starting video processing...")
    Logger.info("📹 Video: #{video_path}")
    Logger.info("📝 Title: #{title}")
    Logger.info("💬 Captions: #{captions_path || "None found"}")
    
    # Start the application
    Mix.Task.run("app.start")
    
    # Process the video
    case process_video(video_path, title, captions_path, fps, quality) do
      {:ok, video_id} ->
        Logger.info("✅ Video processing completed successfully!")
        Logger.info("🆔 Video ID: #{video_id}")
        show_stats(video_id)
        
      {:error, reason} ->
        Logger.error("❌ Video processing failed: #{reason}")
        System.halt(1)
    end
  end
  
  defp process_video(video_path, title, captions_path, fps, quality) do
    # Step 1: Create or find video record (outside transaction)
    Logger.info("📊 Creating video record...")
    video_attrs = %{
      title: title,
      file_path: video_path,
      status: "processing"
    }
    
    video = case Video.create_video(video_attrs) do
      {:ok, video} -> 
        Logger.info("✅ Created new video record (ID: #{video.id})")
        video
      {:error, changeset} ->
        # Check if it's a duplicate file_path error
        case changeset.errors[:file_path] do
          {"has already been taken", _} ->
            existing_video = Video.get_video_by_file_path(video_path)
            Logger.info("✅ Found existing video record (ID: #{existing_video.id})")
            # Clear existing data for re-processing
            Logger.info("🧹 Clearing existing frames and captions...")
            Video.delete_video_frames(existing_video.id)
            Video.delete_video_captions(existing_video.id)
            # Update status
            {:ok, updated_video} = Video.update_video(existing_video, %{status: "processing"})
            updated_video
          _ ->
            raise "Failed to create video: #{inspect(changeset.errors)}"
        end
    end

    # Now run the processing steps
    
    # Step 2: Extract frames using ffmpeg
    Logger.info("🎞️ Extracting frames...")
    frame_paths = extract_frames(video, fps, quality)
    Logger.info("✅ Extracted #{length(frame_paths)} frames")
    
    # Step 3: Get video metadata
    Logger.info("📋 Getting video metadata...")
    video_metadata = get_video_metadata(video_path)
    
    # Calculate duration from frame count if metadata failed
    duration_ms = video_metadata.duration_ms || (length(frame_paths) * 1000)
    Logger.info("✅ Duration: #{duration_ms}ms (#{length(frame_paths)} frames)")
    
    # Step 4: Update video with metadata
    Video.update_video(video, %{
      duration_ms: duration_ms,
      fps: fps,
      frame_count: length(frame_paths)
    })
    
    # Step 5: Parse and store captions
    captions = if captions_path do
      Logger.info("📖 Parsing captions...")
      parse_and_store_captions(video.id, captions_path)
    else
      Logger.info("⚠️ No captions file found, skipping captions")
      []
    end
    Logger.info("✅ Stored #{length(captions)} captions")
    
    # Step 6: Process and store frames with binary data
    Logger.info("💾 Processing and storing frames...")
    frames = process_and_store_frames(video.id, frame_paths, duration_ms)
    Logger.info("✅ Stored #{length(frames)} frames")
    
    # Step 7: Link frames to captions
    if length(captions) > 0 and length(frames) > 0 do
      Logger.info("🔗 Linking frames to captions...")
      links = link_frames_to_captions(frames, captions)
      Logger.info("✅ Created #{length(links)} frame-caption links")
    end
    
    # Step 8: Mark video as completed
    Video.update_video(video, %{
      status: "completed",
      processed_at: DateTime.utc_now()
    })
    
    {:ok, video.id}
  end
  
  defp extract_frames(video, fps, quality) do
    output_dir = "priv/static/frames/video_#{video.id}"
    File.mkdir_p!(output_dir)
    
    processor = VideoProcessor.new(video.file_path,
      output_dir: output_dir,
      fps: fps,
      quality: quality,
      use_hardware_accel: true
    )
    
    case VideoProcessor.extract_frames(processor) do
      {:ok, frame_paths} -> frame_paths
      {:error, reason} -> raise "Frame extraction failed: #{reason}"
    end
  end
  
  defp get_video_metadata(video_path) do
    case VideoProcessor.get_video_info(video_path) do
      {:ok, video_info} ->
        duration_ms = case video_info["format"]["duration"] do
          duration_str when is_binary(duration_str) ->
            {duration_seconds, _} = Float.parse(duration_str)
            trunc(duration_seconds * 1000)
          _ -> nil
        end
        %{duration_ms: duration_ms}
      
      {:error, reason} ->
        Logger.warning("Failed to get video metadata: #{reason}, using defaults")
        # Use frame count * 1000ms as fallback duration (1 fps assumption)
        %{duration_ms: nil}
    end
  end
  
  defp parse_and_store_captions(video_id, captions_path) do
    case SrtParser.parse_file(captions_path) do
      {:ok, subtitle_entries} ->
        caption_data = Enum.map(subtitle_entries, fn entry ->
          %{
            video_id: video_id,
            start_time_ms: entry.start_time,
            end_time_ms: entry.end_time,
            text: entry.text,
            caption_index: entry.index,
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)
        
        {_count, captions} = Repo.insert_all(VideoCaption, caption_data, returning: true)
        captions
        
      {:error, reason} ->
        raise "Caption parsing failed: #{reason}"
    end
  end
  
  defp process_and_store_frames(video_id, frame_paths, duration_ms) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    total_frames = length(frame_paths)
    
    frame_data = frame_paths
    |> Enum.with_index()
    |> Enum.map(fn {frame_path, index} ->
      # Read image data
      image_data = case File.read(frame_path) do
        {:ok, binary} -> binary
        {:error, _} -> nil
      end
      
      # Get file stats
      file_size = case File.stat(frame_path) do
        {:ok, %File.Stat{size: size}} -> size
        {:error, _} -> 0
      end
      
      # Calculate timestamp
      timestamp_ms = if duration_ms && total_frames > 1 do
        trunc((index / (total_frames - 1)) * duration_ms)
      else
        index * 1000
      end
      
      %{
        video_id: video_id,
        frame_number: index,
        timestamp_ms: timestamp_ms,
        file_path: frame_path,
        file_size: file_size,
        width: nil,  # Could extract from image if needed
        height: nil, # Could extract from image if needed
        image_data: image_data,
        compression_ratio: nil,
        inserted_at: now,
        updated_at: now
      }
    end)
    
    Logger.info("💿 Inserting #{length(frame_data)} frames into database...")
    {_count, frames} = Repo.insert_all(VideoFrame, frame_data, returning: true)
    frames
  end
  
  defp link_frames_to_captions(frames, captions) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    
    links = for frame <- frames,
                caption <- captions,
                frame_in_caption_timerange?(frame, caption) do
      %{
        frame_id: frame.id,
        caption_id: caption.id,
        inserted_at: now,
        updated_at: now
      }
    end
    
    if length(links) > 0 do
      {_count, _} = Repo.insert_all(Video.FrameCaption, links)
      links
    else
      []
    end
  end
  
  defp frame_in_caption_timerange?(frame, caption) do
    frame.timestamp_ms >= caption.start_time_ms and
    frame.timestamp_ms <= caption.end_time_ms
  end
  
  defp find_caption_file(video_path) do
    video_dir = Path.dirname(video_path)
    video_basename = Path.basename(video_path, Path.extname(video_path))
    
    srt_patterns = [
      Path.join(video_dir, "#{video_basename}.srt"),
      Path.join(video_dir, "#{video_basename}.en.srt"),
      String.replace(video_path, Path.extname(video_path), ".srt")
    ]
    
    Enum.find(srt_patterns, &File.exists?/1)
  end
  
  defp show_stats(video_id) do
    import Ecto.Query
    
    frame_count = Repo.aggregate(VideoFrame, :count, :id, where: [video_id: video_id])
    caption_count = Repo.aggregate(VideoCaption, :count, :id, where: [video_id: video_id])
    
    link_count = from(fc in Video.FrameCaption,
      join: f in VideoFrame, on: fc.frame_id == f.id,
      where: f.video_id == ^video_id,
      select: count(fc.id)
    ) |> Repo.one()
    
    Logger.info("📊 Final Statistics:")
    Logger.info("   📸 Frames: #{frame_count}")
    Logger.info("   💬 Captions: #{caption_count}")
    Logger.info("   🔗 Frame-Caption Links: #{link_count}")
  end
end