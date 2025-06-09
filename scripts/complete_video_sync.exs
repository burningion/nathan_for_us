#!/usr/bin/env elixir

# Complete Video Processing and Production Sync Script
# IMPORTANT: Requires yt-dlp via ASDF/Python and Phoenix application running
# Usage: elixir scripts/complete_video_sync.exs [youtube_url] [optional_title]
# Or:    elixir scripts/complete_video_sync.exs sync_only [video_id]
#
# Prerequisites:
# 1. pip install yt-dlp (via asdf python)
# 2. Phoenix app running: iex -S mix (for GenStage processing)
# 3. FFmpeg with hardware acceleration support

defmodule CompleteVideoSync do
  @moduledoc """
  Complete pipeline for processing YouTube videos and syncing to production.
  
  This script handles:
  1. Downloading YouTube videos with captions
  2. Processing videos locally (frames + captions)
  3. Exporting processed data
  4. Syncing to production database
  5. Creating frame-caption links
  6. Verifying search functionality
  """

  require Logger

  def main(args) do
    case args do
      ["sync_only", video_id] ->
        video_id = String.to_integer(video_id)
        sync_video_to_production(video_id)
        
      ["sync_only"] ->
        sync_all_completed_videos()
        
      [youtube_url] ->
        full_pipeline(youtube_url)
        
      [youtube_url, title] ->
        full_pipeline(youtube_url, title)
        
      [] ->
        show_usage()
        
      _ ->
        show_usage()
    end
  end

  defp show_usage do
    IO.puts """
    Complete Video Processing and Production Sync Script
    
    Usage:
      # Process new YouTube video end-to-end
      elixir scripts/complete_video_sync.exs "https://youtube.com/watch?v=..." ["Custom Title"]
      
      # Sync specific video to production
      elixir scripts/complete_video_sync.exs sync_only 4
      
      # Sync all completed videos to production  
      elixir scripts/complete_video_sync.exs sync_only
    
    Requirements:
    - yt-dlp installed (pip install yt-dlp)
    - gigalixir CLI configured
    - Local development environment running
    """
  end

  defp full_pipeline(youtube_url, custom_title \\ nil) do
    Logger.info("Starting complete video processing pipeline for: #{youtube_url}")
    
    # Step 1: Download video and captions
    Logger.info("Step 1: Downloading video and captions...")
    video_path = download_youtube_video(youtube_url, custom_title)
    
    if video_path do
      # Step 2: Process video locally
      Logger.info("Step 2: Processing video locally...")
      case process_video_locally(video_path) do
        {:ok, video} ->
          Logger.info("Video processed successfully: #{video.title} (ID: #{video.id})")
          
          # Step 3: Sync to production
          Logger.info("Step 3: Syncing to production...")
          sync_video_to_production(video.id)
          
        {:error, reason} ->
          Logger.error("Failed to process video: #{inspect(reason)}")
      end
    else
      Logger.error("Failed to download video")
    end
  end

  defp download_youtube_video(youtube_url, custom_title) do
    # Create downloads directory
    File.mkdir_p!("downloads")
    
    # Download with yt-dlp
    download_cmd = [
      "yt-dlp",
      "-f", "best[height<=720]",
      "--write-sub",
      "--write-auto-sub", 
      "--sub-lang", "en",
      "--convert-subs", "srt",
      "-o", "downloads/%(title)s.%(ext)s",
      youtube_url
    ]
    
    case System.cmd("/Users/robertgrayson/.asdf/shims/yt-dlp", Enum.drop(download_cmd, 1), stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Download completed")
        IO.puts(output)
        
        # Find the downloaded video file
        case File.ls("downloads") do
          {:ok, files} ->
            video_file = Enum.find(files, &String.ends_with?(&1, ".mp4"))
            if video_file do
              video_path = Path.join("downloads", video_file)
              
              # Rename if custom title provided
              if custom_title do
                extension = Path.extname(video_file)
                new_name = "#{custom_title}#{extension}"
                new_path = Path.join("downloads", new_name)
                File.rename!(video_path, new_path)
                
                # Also rename caption file if it exists
                caption_file = Enum.find(files, &String.contains?(&1, ".en.srt"))
                if caption_file do
                  old_caption_path = Path.join("downloads", caption_file)
                  new_caption_name = "#{custom_title}.en.srt"
                  new_caption_path = Path.join("downloads", new_caption_name)
                  File.rename!(old_caption_path, new_caption_path)
                end
                
                new_path
              else
                video_path
              end
            else
              Logger.error("No video file found in downloads")
              nil
            end
            
          {:error, reason} ->
            Logger.error("Failed to list downloads directory: #{inspect(reason)}")
            nil
        end
        
      {output, exit_code} ->
        Logger.error("yt-dlp failed with exit code #{exit_code}")
        IO.puts(output)
        nil
    end
  end

  defp process_video_locally(video_path) do
    # Start the application if not already started
    Application.ensure_all_started(:nathan_for_us)
    
    # Process the video
    NathanForUs.VideoProcessing.process_video(video_path)
  end

  defp sync_all_completed_videos do
    Logger.info("Syncing all completed videos to production...")
    
    Application.ensure_all_started(:nathan_for_us)
    
    completed_videos = NathanForUs.Video.list_videos_by_status("completed")
    
    if Enum.empty?(completed_videos) do
      Logger.info("No completed videos found to sync")
    else
      Logger.info("Found #{length(completed_videos)} completed videos to sync")
      
      Enum.each(completed_videos, fn video ->
        Logger.info("Syncing video #{video.id}: #{video.title}")
        sync_video_to_production(video.id)
      end)
    end
  end

  defp sync_video_to_production(video_id) do
    Logger.info("Syncing video #{video_id} to production...")
    
    # Step 1: Export video data
    Logger.info("  1. Exporting video data...")
    export_file = export_video_data(video_id)
    
    if export_file do
      # Step 2: Upload to production
      Logger.info("  2. Uploading to production database...")
      upload_to_production(export_file)
      
      # Step 3: Create frame-caption links
      Logger.info("  3. Creating frame-caption links...")
      create_frame_caption_links(video_id)
      
      # Step 4: Verify search functionality
      Logger.info("  4. Verifying search functionality...")
      verify_search_functionality(video_id)
      
      # Cleanup
      File.rm(export_file)
      Logger.info("Sync completed for video #{video_id}")
    else
      Logger.error("Failed to export video data")
    end
  end

  defp export_video_data(video_id) do
    Application.ensure_all_started(:nathan_for_us)
    
    export_file = "/tmp/video_#{video_id}_export.sql"
    
    # Get database config
    config = Application.get_env(:nathan_for_us, NathanForUs.Repo)
    username = config[:username]
    password = config[:password]
    database = config[:database]
    hostname = config[:hostname] || "localhost"
    
    # Export frames without binary data using custom SQL
    frame_query = """
    SELECT 'INSERT INTO video_frames (video_id, frame_number, timestamp_ms, file_path, file_size, width, height, inserted_at, updated_at) VALUES (' ||
           video_id || ',' || 
           frame_number || ',' || 
           timestamp_ms || ',''' || 
           file_path || ''',' || 
           COALESCE(file_size::text, 'NULL') || ',' || 
           COALESCE(width::text, 'NULL') || ',' || 
           COALESCE(height::text, 'NULL') || 
           ', NOW(), NOW());'
    FROM video_frames 
    WHERE video_id = #{video_id}
    ORDER BY id;
    """
    
    # Export captions
    caption_query = """
    SELECT 'INSERT INTO video_captions (video_id, start_time_ms, end_time_ms, text, caption_index, inserted_at, updated_at) VALUES (' ||
           video_id || ',' || 
           start_time_ms || ',' || 
           end_time_ms || ',''' || 
           REPLACE(text, '''', '''''') || ''',' || 
           COALESCE(caption_index::text, 'NULL') || 
           ', NOW(), NOW());'
    FROM video_captions 
    WHERE video_id = #{video_id}
    ORDER BY id;
    """
    
    # Export video metadata
    video_query = """
    SELECT 'INSERT INTO videos (id, title, file_path, duration_ms, fps, frame_count, status, processed_at, metadata, inserted_at, updated_at) VALUES (' ||
           id || ',''' || 
           REPLACE(title, '''', '''''') || ''',''' || 
           file_path || ''',' || 
           COALESCE(duration_ms::text, 'NULL') || ',' || 
           COALESCE(fps::text, 'NULL') || ',' || 
           COALESCE(frame_count::text, 'NULL') || ',''' || 
           status || ''',''' || 
           COALESCE(processed_at::text, 'NULL') || ''',' || 
           COALESCE(metadata::text, 'NULL') || 
           ', NOW(), NOW()) ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, frame_count = EXCLUDED.frame_count, processed_at = EXCLUDED.processed_at;'
    FROM videos 
    WHERE id = #{video_id};
    """
    
    # Create export file
    File.write!(export_file, "-- Video #{video_id} Export\nBEGIN;\n\n")
    
    # Add video data
    case System.cmd("psql", [
      "-h", hostname,
      "-U", username, 
      "-d", database,
      "-t",
      "-c", video_query
    ], env: [{"PGPASSWORD", password}], stderr_to_stdout: true) do
      {output, 0} ->
        File.write!(export_file, "-- Video metadata\n#{String.trim(output)}\n\n", [:append])
        
      {error, _} ->
        Logger.error("Failed to export video metadata: #{error}")
        nil
    end
    
    # Add frame data
    case System.cmd("psql", [
      "-h", hostname,
      "-U", username,
      "-d", database, 
      "-t",
      "-c", frame_query
    ], env: [{"PGPASSWORD", password}], stderr_to_stdout: true) do
      {output, 0} ->
        File.write!(export_file, "-- Video frames\n#{String.trim(output)}\n\n", [:append])
        
      {error, _} ->
        Logger.error("Failed to export frames: #{error}")
        nil
    end
    
    # Add caption data
    case System.cmd("psql", [
      "-h", hostname,
      "-U", username,
      "-d", database,
      "-t", 
      "-c", caption_query
    ], env: [{"PGPASSWORD", password}], stderr_to_stdout: true) do
      {output, 0} ->
        File.write!(export_file, "-- Video captions\n#{String.trim(output)}\n\n", [:append])
        
      {error, _} ->
        Logger.error("Failed to export captions: #{error}")
        nil
    end
    
    File.write!(export_file, "COMMIT;\n", [:append])
    
    Logger.info("Exported video data to #{export_file}")
    export_file
  end

  defp upload_to_production(export_file) do
    case System.cmd("sh", ["-c", "gigalixir pg:psql < #{export_file}"], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Successfully uploaded to production")
        IO.puts(output)
        true
        
      {error, exit_code} ->
        Logger.error("Failed to upload to production (exit code #{exit_code}): #{error}")
        false
    end
  end

  defp create_frame_caption_links(video_id) do
    link_sql = """
    SELECT setval('frame_captions_id_seq', (SELECT COALESCE(MAX(id), 0) FROM frame_captions));
    INSERT INTO frame_captions (frame_id, caption_id, inserted_at, updated_at)
    SELECT DISTINCT f.id, c.id, NOW(), NOW()
    FROM video_frames f
    JOIN video_captions c ON f.video_id = c.video_id
    WHERE f.timestamp_ms >= c.start_time_ms 
      AND f.timestamp_ms <= c.end_time_ms
      AND f.video_id = #{video_id}
      AND NOT EXISTS (
        SELECT 1 FROM frame_captions fc 
        WHERE fc.frame_id = f.id AND fc.caption_id = c.id
      );
    """
    
    temp_file = "/tmp/links_#{video_id}.sql"
    File.write!(temp_file, link_sql)
    
    case System.cmd("sh", ["-c", "gigalixir pg:psql < #{temp_file}"], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Successfully created frame-caption links")
        IO.puts(output)
        true
        
      {error, exit_code} ->
        Logger.error("Failed to create frame-caption links (exit code #{exit_code}): #{error}")
        false
    end
    
    File.rm(temp_file)
  end

  defp verify_search_functionality(video_id) do
    # Test a simple search query
    test_sql = """
    SELECT COUNT(*) as search_results
    FROM video_frames f
    JOIN frame_captions fc ON fc.frame_id = f.id
    JOIN video_captions c ON c.id = fc.caption_id
    WHERE f.video_id = #{video_id}
    LIMIT 5;
    """
    
    temp_file = "/tmp/test_#{video_id}.sql"
    File.write!(temp_file, test_sql)
    
    case System.cmd("sh", ["-c", "gigalixir pg:psql < #{temp_file}"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, "search_results") do
          Logger.info("Search functionality verified for video #{video_id}")
          IO.puts("Search test results:")
          IO.puts(output)
          true
        else
          Logger.warning("Search test returned unexpected results")
          false
        end
        
      {error, exit_code} ->
        Logger.error("Search verification failed (exit code #{exit_code}): #{error}")
        false
    end
    
    File.rm(temp_file)
  end

  defp get_final_stats do
    stats_sql = """
    SELECT v.id, v.title, v.status,
           COUNT(DISTINCT f.id) as frame_count,
           COUNT(DISTINCT c.id) as caption_count,
           COUNT(DISTINCT fc.id) as link_count
    FROM videos v
    LEFT JOIN video_frames f ON v.id = f.video_id  
    LEFT JOIN video_captions c ON v.id = c.video_id
    LEFT JOIN frame_captions fc ON f.id = fc.frame_id
    GROUP BY v.id, v.title, v.status
    ORDER BY v.id;
    """
    
    temp_file = "/tmp/final_stats.sql"
    File.write!(temp_file, stats_sql)
    
    case System.cmd("sh", ["-c", "gigalixir pg:psql < #{temp_file}"], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Production database statistics:")
        IO.puts(output)
        
      {error, exit_code} ->
        Logger.error("Failed to get stats (exit code #{exit_code}): #{error}")
    end
    
    File.rm(temp_file)
  end
end

# Run the script
System.argv() |> CompleteVideoSync.main()