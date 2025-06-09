#!/usr/bin/env elixir

# Binary Image Data Sync Script
# Syncs the actual JPEG binary data from local to production

defmodule BinaryImageSync do
  require Logger

  def main(args) do
    case args do
      [video_id] ->
        sync_video_images(String.to_integer(video_id))
      [] ->
        sync_all_missing_images()
      _ ->
        show_usage()
    end
  end

  defp show_usage do
    IO.puts """
    Binary Image Data Sync Script
    
    Usage:
      # Sync images for specific video
      elixir scripts/sync_binary_images.exs 3
      
      # Sync all missing images
      elixir scripts/sync_binary_images.exs
    """
  end

  defp sync_all_missing_images do
    Logger.info("Syncing all missing image data...")
    sync_video_images(3)
    sync_video_images(4)
  end

  defp sync_video_images(video_id) do
    Logger.info("Syncing image data for video #{video_id}")
    
    # Export frames in small batches to avoid memory issues
    batch_size = 50
    total_frames = get_frame_count(video_id)
    
    Logger.info("Found #{total_frames} frames to sync for video #{video_id}")
    
    0..div(total_frames - 1, batch_size)
    |> Enum.each(fn batch_num ->
      offset = batch_num * batch_size
      Logger.info("Processing batch #{batch_num + 1}/#{div(total_frames - 1, batch_size) + 1} (offset: #{offset})")
      
      sync_frame_batch(video_id, offset, batch_size)
      Process.sleep(500) # Small delay to avoid overwhelming databases
    end)
    
    Logger.info("Completed syncing #{total_frames} frames for video #{video_id}")
  end

  defp get_frame_count(video_id) do
    config = get_local_db_config()
    
    {output, 0} = System.cmd("psql", [
      "-h", config.hostname,
      "-U", config.username,
      "-d", config.database,
      "-t",
      "-c", "SELECT COUNT(*) FROM video_frames WHERE video_id = #{video_id} AND image_data IS NOT NULL;"
    ], env: [{"PGPASSWORD", config.password}])
    
    output |> String.trim() |> String.to_integer()
  end

  defp sync_frame_batch(video_id, offset, limit) do
    # Create a temporary CSV export with base64 encoded images
    temp_file = "/tmp/batch_#{video_id}_#{offset}.csv"
    
    export_batch_to_csv(video_id, offset, limit, temp_file)
    import_batch_from_csv(temp_file)
    
    File.rm(temp_file)
  end

  defp export_batch_to_csv(video_id, offset, limit, csv_file) do
    config = get_local_db_config()
    
    export_sql = """
    \\copy (
      SELECT id, 
             encode(image_data, 'base64') as image_b64,
             compression_ratio
      FROM video_frames 
      WHERE video_id = #{video_id} 
        AND image_data IS NOT NULL
      ORDER BY id
      LIMIT #{limit} OFFSET #{offset}
    ) TO '#{csv_file}' WITH CSV HEADER
    """
    
    File.write!("/tmp/export_batch.sql", export_sql)
    
    {_output, 0} = System.cmd("psql", [
      "-h", config.hostname,
      "-U", config.username,
      "-d", config.database,
      "-f", "/tmp/export_batch.sql"
    ], env: [{"PGPASSWORD", config.password}])
    
    File.rm("/tmp/export_batch.sql")
  end

  defp import_batch_from_csv(csv_file) do
    # Check if file has data
    case File.read(csv_file) do
      {:ok, content} when byte_size(content) > 50 ->
        import_sql = """
        CREATE TEMP TABLE IF NOT EXISTS batch_updates (
          id INTEGER,
          image_b64 TEXT,
          compression_ratio DOUBLE PRECISION
        );
        
        \\copy batch_updates FROM '#{csv_file}' WITH CSV HEADER;
        
        UPDATE video_frames 
        SET image_data = decode(bu.image_b64, 'base64'),
            compression_ratio = bu.compression_ratio
        FROM batch_updates bu
        WHERE video_frames.id = bu.id;
        
        DROP TABLE batch_updates;
        """
        
        File.write!("/tmp/import_batch.sql", import_sql)
        
        case System.cmd("sh", ["-c", "gigalixir pg:psql < /tmp/import_batch.sql"], stderr_to_stdout: true) do
          {output, 0} ->
            Logger.info("Successfully imported batch")
            
          {error, _} ->
            Logger.error("Failed to import batch: #{error}")
        end
        
        File.rm("/tmp/import_batch.sql")
        
      _ ->
        Logger.info("No data in batch file, skipping")
    end
  end

  defp get_local_db_config do
    # Parse config from dev.exs
    config_content = File.read!("config/dev.exs")
    
    username = Regex.run(~r/username: "([^"]*)"/, config_content) |> List.last()
    password = Regex.run(~r/password: "([^"]*)"/, config_content) |> List.last()
    database = Regex.run(~r/database: "([^"]*)"/, config_content) |> List.last()
    hostname = "localhost"
    
    %{
      username: username,
      password: password,
      database: database,
      hostname: hostname
    }
  end
end

# Run the script
System.argv() |> BinaryImageSync.main()