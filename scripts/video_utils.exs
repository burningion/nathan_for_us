#!/usr/bin/env elixir

# Video Utilities Script
# Usage: elixir scripts/video_utils.exs [command] [args...]

defmodule VideoUtils do
  @moduledoc """
  Utility commands for video management and debugging.
  """

  require Logger

  def main(args) do
    case args do
      ["status"] ->
        show_status()
        
      ["test_search", video_id, search_term] ->
        test_search(String.to_integer(video_id), search_term)
        
      ["stats"] ->
        show_production_stats()
        
      ["list_local"] ->
        list_local_videos()
        
      ["fix_sequence"] ->
        fix_production_sequences()
        
      ["check_links", video_id] ->
        check_frame_caption_links(String.to_integer(video_id))
        
      [] ->
        show_usage()
        
      _ ->
        show_usage()
    end
  end

  defp show_usage do
    IO.puts """
    Video Utilities Script
    
    Commands:
      status           - Show overall system status
      stats            - Show production database statistics
      list_local       - List local videos and their status
      test_search <video_id> <term> - Test search functionality
      fix_sequence     - Fix production database sequences
      check_links <video_id> - Check frame-caption links for video
      
    Examples:
      elixir scripts/video_utils.exs status
      elixir scripts/video_utils.exs test_search 4 "train"
      elixir scripts/video_utils.exs stats
    """
  end

  defp show_status do
    Logger.info("=== System Status ===")
    
    # Check local status
    Application.ensure_all_started(:nathan_for_us)
    
    local_videos = NathanForUs.Video.list_videos()
    Logger.info("Local videos: #{length(local_videos)}")
    
    Enum.each(local_videos, fn video ->
      frame_stats = NathanForUs.Video.get_frame_stats(video.id)
      caption_stats = NathanForUs.Video.get_caption_stats(video.id)
      
      IO.puts "  #{video.id}: #{video.title}"
      IO.puts "    Status: #{video.status}"
      IO.puts "    Frames: #{frame_stats.count || 0}"
      IO.puts "    Captions: #{caption_stats.count || 0}"
    end)
    
    # Check production status
    Logger.info("Production status:")
    show_production_stats()
  end

  defp show_production_stats do
    stats_sql = """
    SELECT 
      'Videos: ' || COUNT(DISTINCT v.id) ||
      ', Frames: ' || COUNT(DISTINCT f.id) ||
      ', Captions: ' || COUNT(DISTINCT c.id) ||
      ', Links: ' || COUNT(DISTINCT fc.id) as summary
    FROM videos v
    LEFT JOIN video_frames f ON v.id = f.video_id  
    LEFT JOIN video_captions c ON v.id = c.video_id
    LEFT JOIN frame_captions fc ON f.id = fc.frame_id;
    
    SELECT v.id, LEFT(v.title, 50) as title, v.status,
           COUNT(DISTINCT f.id) as frames,
           COUNT(DISTINCT c.id) as captions,
           COUNT(DISTINCT fc.id) as links
    FROM videos v
    LEFT JOIN video_frames f ON v.id = f.video_id  
    LEFT JOIN video_captions c ON v.id = c.video_id
    LEFT JOIN frame_captions fc ON f.id = fc.frame_id
    GROUP BY v.id, v.title, v.status
    ORDER BY v.id;
    """
    
    # Write to temp file and use that
    temp_file = "/tmp/stats_query.sql"
    File.write!(temp_file, stats_sql)
    
    case System.cmd("sh", ["-c", "gigalixir pg:psql < #{temp_file}"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts(output)
        
      {error, _exit_code} ->
        Logger.error("Failed to get production stats: #{error}")
    end
    
    File.rm(temp_file)
  end

  defp list_local_videos do
    Application.ensure_all_started(:nathan_for_us)
    
    videos = NathanForUs.Video.list_videos()
    
    Logger.info("=== Local Videos ===")
    
    Enum.each(videos, fn video ->
      frame_stats = NathanForUs.Video.get_frame_stats(video.id)
      caption_stats = NathanForUs.Video.get_caption_stats(video.id)
      
      IO.puts """
      ID: #{video.id}
      Title: #{video.title}
      Status: #{video.status}
      File: #{video.file_path}
      Frames: #{frame_stats.count || 0}
      Captions: #{caption_stats.count || 0}
      Duration: #{format_duration(video.duration_ms)}
      Processed: #{video.processed_at}
      ---
      """
    end)
  end

  defp test_search(video_id, search_term) do
    Logger.info("Testing search for '#{search_term}' in video #{video_id}")
    
    search_sql = """
    SELECT f.frame_number, f.timestamp_ms, LEFT(c.text, 100) as caption_excerpt
    FROM video_frames f
    JOIN frame_captions fc ON fc.frame_id = f.id
    JOIN video_captions c ON c.id = fc.caption_id
    WHERE c.text ILIKE '%#{search_term}%' AND f.video_id = #{video_id}
    ORDER BY f.timestamp_ms
    LIMIT 10;
    """
    
    temp_file = "/tmp/search_query.sql"
    File.write!(temp_file, search_sql)
    
    case System.cmd("sh", ["-c", "gigalixir pg:psql < #{temp_file}"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("Search results:")
        IO.puts(output)
        
      {error, _exit_code} ->
        Logger.error("Search test failed: #{error}")
    end
    
    File.rm(temp_file)
  end

  defp fix_production_sequences do
    Logger.info("Fixing production database sequences...")
    
    fix_sql = """
    SELECT setval('videos_id_seq', (SELECT COALESCE(MAX(id), 1) FROM videos));
    SELECT setval('video_frames_id_seq', (SELECT COALESCE(MAX(id), 1) FROM video_frames));
    SELECT setval('video_captions_id_seq', (SELECT COALESCE(MAX(id), 1) FROM video_captions));
    SELECT setval('frame_captions_id_seq', (SELECT COALESCE(MAX(id), 1) FROM frame_captions));
    """
    
    temp_file = "/tmp/fix_query.sql"
    File.write!(temp_file, fix_sql)
    
    case System.cmd("sh", ["-c", "gigalixir pg:psql < #{temp_file}"], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Sequences fixed successfully")
        IO.puts(output)
        
      {error, _exit_code} ->
        Logger.error("Failed to fix sequences: #{error}")
    end
    
    File.rm(temp_file)
  end

  defp check_frame_caption_links(video_id) do
    Logger.info("Checking frame-caption links for video #{video_id}")
    
    check_sql = """
    SELECT 
      'Video #{video_id} Analysis:' as info,
      COUNT(DISTINCT f.id) as total_frames,
      COUNT(DISTINCT c.id) as total_captions,
      COUNT(DISTINCT fc.id) as existing_links,
      COUNT(DISTINCT CASE WHEN f.timestamp_ms >= c.start_time_ms AND f.timestamp_ms <= c.end_time_ms THEN f.id END) as possible_links
    FROM video_frames f
    CROSS JOIN video_captions c
    LEFT JOIN frame_captions fc ON fc.frame_id = f.id AND fc.caption_id = c.id
    WHERE f.video_id = #{video_id} AND c.video_id = #{video_id};
    """
    
    temp_file = "/tmp/check_query.sql"
    File.write!(temp_file, check_sql)
    
    case System.cmd("sh", ["-c", "gigalixir pg:psql < #{temp_file}"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts(output)
        
      {error, _exit_code} ->
        Logger.error("Link check failed: #{error}")
    end
    
    File.rm(temp_file)
  end

  defp format_duration(nil), do: "Unknown"
  defp format_duration(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
end

# Run the script
System.argv() |> VideoUtils.main()