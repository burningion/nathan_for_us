defmodule NathanForUs.VideoProcessor do
  @moduledoc """
  Elixir wrapper around ffmpeg for extracting frames from video files.
  Optimized for MacBook hardware acceleration and batch processing.
  """

  require Logger

  @default_output_dir "priv/static/frames"
  @default_fps 1
  @default_quality 2

  defstruct [
    :video_path,
    :output_dir,
    :fps,
    :quality,
    :use_hardware_accel,
    :scene_detection,
    jpeg_quality: 75,  # JPEG compression quality (0-100)
    store_binary: false  # Whether to return binary data instead of file paths
  ]

  @type t :: %__MODULE__{
          video_path: String.t(),
          output_dir: String.t(),
          fps: integer(),
          quality: integer(),
          use_hardware_accel: boolean(),
          scene_detection: boolean()
        }

  @doc """
  Creates a new VideoProcessor configuration.

  ## Options
  - `:output_dir` - Directory to save extracted frames (default: "priv/static/frames")
  - `:fps` - Frames per second to extract (default: 1)
  - `:quality` - JPEG quality 1-31, lower is better (default: 2)
  - `:use_hardware_accel` - Use VideoToolbox on macOS (default: true)
  - `:scene_detection` - Only extract frames on scene changes (default: false)
  """
  def new(video_path, opts \\ []) do
    %__MODULE__{
      video_path: video_path,
      output_dir: Keyword.get(opts, :output_dir, @default_output_dir),
      fps: Keyword.get(opts, :fps, @default_fps),
      quality: Keyword.get(opts, :quality, @default_quality),
      use_hardware_accel: Keyword.get(opts, :use_hardware_accel, true),
      scene_detection: Keyword.get(opts, :scene_detection, false)
    }
  end

  @doc """
  Extracts frames from video using ffmpeg.
  Returns {:ok, frame_paths} or {:error, reason}.
  """
  def extract_frames(%__MODULE__{} = config) do
    with :ok <- validate_video_file(config.video_path),
         :ok <- ensure_output_directory(config.output_dir),
         {_output, 0} <- run_ffmpeg_command(config) do
      frame_paths = list_extracted_frames(config.output_dir)
      Logger.info("Extracted #{length(frame_paths)} frames from #{config.video_path}")
      {:ok, frame_paths}
    else
      {output, exit_code} ->
        Logger.error("ffmpeg failed with exit code #{exit_code}: #{output}")
        {:error, "ffmpeg extraction failed: #{output}"}

      error ->
        {:error, error}
    end
  end

  @doc """
  Gets video metadata using ffprobe.
  Returns {:ok, metadata} or {:error, reason}.
  """
  def get_video_info(video_path) do
    cmd = [
      "ffprobe",
      "-v", "quiet",
      "-print_format", "json",
      "-show_format",
      "-show_streams",
      video_path
    ]

    case System.cmd("ffprobe", cmd, stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, metadata} -> {:ok, metadata}
          {:error, _} -> {:error, "Failed to parse video metadata"}
        end

      {output, _exit_code} ->
        {:error, "ffprobe failed: #{output}"}
    end
  end

  @doc """
  Estimates the number of frames that would be extracted.
  """
  def estimate_frame_count(video_path, fps \\ @default_fps) do
    with {:ok, metadata} <- get_video_info(video_path),
         {:ok, duration} <- extract_duration(metadata) do
      estimated_frames = trunc(duration * fps)
      {:ok, estimated_frames}
    else
      error -> error
    end
  end

  # Private functions

  defp validate_video_file(video_path) do
    if File.exists?(video_path) do
      :ok
    else
      {:error, "Video file not found: #{video_path}"}
    end
  end

  defp ensure_output_directory(output_dir) do
    case File.mkdir_p(output_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create output directory: #{reason}"}
    end
  end

  defp run_ffmpeg_command(%__MODULE__{} = config) do
    cmd = build_ffmpeg_command(config)
    Logger.info("Running ffmpeg: #{Enum.join(cmd, " ")}")

    System.cmd("ffmpeg", cmd, stderr_to_stdout: true) |> IO.inspect
  end

  defp build_ffmpeg_command(%__MODULE__{} = config) do
    base_cmd = []

    base_cmd
    |> maybe_add_hardware_accel(config.use_hardware_accel)
    |> add_input_file(config.video_path)
    |> add_video_filters(config)
    |> add_output_options(config)
    |> add_output_pattern(config.output_dir)
  end

  defp maybe_add_hardware_accel(cmd, true) do
    cmd ++ ["-hwaccel", "videotoolbox"]
  end
  defp maybe_add_hardware_accel(cmd, false), do: cmd

  defp add_input_file(cmd, video_path) do
    cmd ++ ["-i", video_path]
  end

  defp add_video_filters(cmd, %{scene_detection: true, fps: fps}) do
    # Combine scene detection with fps limiting
    filter = "select=gt(scene\\,0.4),fps=#{fps}"
    cmd ++ ["-vf", filter, "-vsync", "vfr"]
  end
  defp add_video_filters(cmd, %{scene_detection: false, fps: fps}) do
    cmd ++ ["-vf", "fps=#{fps}"]
  end

  defp add_output_options(cmd, %{quality: quality}) do
    cmd ++ ["-q:v", to_string(quality)]
  end

  defp add_output_pattern(cmd, output_dir) do
    pattern = Path.join(output_dir, "frame_%08d.jpg")
    cmd ++ [pattern]
  end

  defp list_extracted_frames(output_dir) do
    case File.ls(output_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".jpg"))
        |> Enum.map(&Path.join(output_dir, &1))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  defp extract_duration(%{"format" => %{"duration" => duration_str}}) do
    case Float.parse(duration_str) do
      {duration, _} -> {:ok, duration}
      :error -> {:error, "Invalid duration format"}
    end
  end
  defp extract_duration(_metadata) do
    {:error, "Duration not found in metadata"}
  end

  @doc """
  Compresses an existing JPEG file and returns binary data.
  """
  def compress_jpeg_file(file_path, quality \\ 75) do
    with true <- File.exists?(file_path),
         {:ok, original_data} <- File.read(file_path) do
      compress_jpeg_binary(original_data, quality)
    else
      false -> {:error, "File not found: #{file_path}"}
      error -> error
    end
  end

  @doc """
  Compresses JPEG binary data using ImageMagick convert.
  """
  def compress_jpeg_binary(binary_data, quality \\ 75) when is_binary(binary_data) do
    # Create temporary files for input and output
    temp_input = "/tmp/temp_input_#{:rand.uniform(10000)}.jpg"
    temp_output = "/tmp/temp_output_#{:rand.uniform(10000)}.jpg"

    try do
      # Write binary data to temp file
      :ok = File.write!(temp_input, binary_data)

      # Use ImageMagick to compress (use 'magick' instead of deprecated 'convert')
      {_output, 0} = System.cmd("magick", [
        temp_input,
        "-quality", "#{quality}",
        "-strip",  # Remove metadata
        temp_output
      ])

      # Read compressed data
      {:ok, compressed_data} = File.read(temp_output)

      # Calculate compression ratio
      original_size = byte_size(binary_data)
      compressed_size = byte_size(compressed_data)
      compression_ratio = compressed_size / original_size

      {:ok, compressed_data, compression_ratio}
    rescue
      error -> {:error, "Compression failed: #{inspect(error)}"}
    after
      # Clean up temp files
      File.rm(temp_input)
      File.rm(temp_output)
    end
  end

  @doc """
  Extracts frames and returns them as compressed binary data instead of files.
  """
  def extract_frames_as_binary(%__MODULE__{store_binary: true} = config) do
    # First extract frames normally
    case extract_frames(config) do
      {:ok, frame_paths} ->
        # Compress each frame and collect binary data
        frames_with_binary =
          frame_paths
          |> Enum.with_index()
          |> Enum.map(fn {path, index} ->
            {:ok, compressed_data, compression_ratio} = compress_jpeg_file(path, config.jpeg_quality)

            %{
              frame_number: index,
              timestamp_ms: index * 1000,  # Assuming 1 fps
              image_data: compressed_data,
              compression_ratio: compression_ratio,
              file_size: byte_size(compressed_data)
            }
          end)

        # Clean up temporary files
        Enum.each(frame_paths, &File.rm/1)
        File.rmdir(config.output_dir)

        {:ok, frames_with_binary}

      error -> error
    end
  end

  def extract_frames_as_binary(config) do
    # If store_binary is false, use normal extraction
    extract_frames(config)
  end

  @doc """
  Process a complete video with captions and store everything in the database.

  This function:
  1. Creates a video record
  2. Extracts frames from the video
  3. Parses caption file
  4. Links frames with captions
  5. Stores everything in the database
  """
  def process_video_with_captions(video_id, video_path, caption_path) do
    alias NathanForUs.{Video, SrtParser, Repo}
    alias NathanForUs.Video.{VideoFrame, VideoCaption, FrameCaption}

    Logger.info("Starting video processing for video_id: #{video_id}")

    try do
      # Get video info
      {:ok, metadata} = get_video_info(video_path)

      # Extract video stream info
      video_stream = Enum.find(metadata["streams"], fn stream ->
        stream["codec_type"] == "video"
      end)

      duration_ms = round(String.to_float(metadata["format"]["duration"]) * 1000)
      width = video_stream["width"]
      height = video_stream["height"]
      frame_rate = parse_frame_rate(video_stream["r_frame_rate"])

      # Update video with metadata
      video = Video.get_video!(video_id)
      {:ok, video} = Video.update_video(video, %{
        duration_ms: duration_ms,
        width: width,
        height: height,
        frame_rate: frame_rate
      })

      Logger.info("Updated video metadata: #{width}x#{height}, #{duration_ms}ms")

      # Parse captions
      Logger.info("Parsing captions from: #{caption_path}")
      {:ok, captions} = SrtParser.parse_file(caption_path)

      # Store captions in database
      caption_records = Enum.map(captions, fn caption ->
        %{
          video_id: video_id,
          text: caption.text,
          start_time_ms: caption.start_time_ms,
          end_time_ms: caption.end_time_ms,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end)

      {_count, caption_records} = Repo.insert_all(VideoCaption, caption_records, returning: true)
      Logger.info("Inserted #{length(caption_records)} captions")

      # Extract frames with binary data
      config = new(video_path, [
        fps: 1,
        store_binary: true,
        jpeg_quality: 85
      ])

      Logger.info("Extracting frames from video...")
      {:ok, frames} = extract_frames_as_binary(config)

      # Process frames in batches to avoid memory issues
      batch_size = 100
      total_frames = length(frames)
      Logger.info("Processing #{total_frames} frames in batches of #{batch_size}")

      frames
      |> Enum.with_index(1)
      |> Enum.chunk_every(batch_size)
      |> Enum.each(fn batch ->
        # Prepare frame records for batch insert
        frame_records = Enum.map(batch, fn {frame_data, frame_number} ->
          %{
            video_id: video_id,
            frame_number: frame_number,
            timestamp_ms: round(frame_data.timestamp_ms),
            image_data: frame_data.image_data,
            file_size: frame_data.file_size,
            width: width,
            height: height,
            compression_ratio: frame_data.compression_ratio,
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)

        # Insert frames
        {_count, inserted_frames} = Repo.insert_all(VideoFrame, frame_records, returning: true)

        # Link frames with captions
        frame_caption_links =
          for frame <- inserted_frames do
            # Find captions that overlap with this frame's timestamp
            matching_captions = Enum.filter(caption_records, fn caption ->
              frame.timestamp_ms >= caption.start_time_ms and
              frame.timestamp_ms <= caption.end_time_ms
            end)

            # Create frame-caption links
            Enum.map(matching_captions, fn caption ->
              %{
                frame_id: frame.id,
                caption_id: caption.id,
                inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
                updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
              }
            end)
          end
          |> List.flatten()

        # Insert frame-caption links if any exist
        if length(frame_caption_links) > 0 do
          Repo.insert_all(FrameCaption, frame_caption_links)
        end

        batch_end = List.last(batch) |> elem(1)
        Logger.info("Processed batch: frames #{batch_end - length(batch) + 1}-#{batch_end} of #{total_frames}")
      end)

      # Update video frame count
      frame_count = Repo.aggregate(VideoFrame, :count, :id, where: [video_id: video_id])
      Video.update_video(video, %{frame_count: frame_count})

      Logger.info("Video processing complete: #{frame_count} frames processed")
      {:ok, %{video: video, frame_count: frame_count, caption_count: length(caption_records)}}

    rescue
      error ->
        Logger.error("Video processing failed: #{inspect(error)}")
        {:error, "Processing failed: #{inspect(error)}"}
    end
  end

  defp parse_frame_rate(frame_rate_str) when is_binary(frame_rate_str) do
    case String.split(frame_rate_str, "/") do
      [numerator, denominator] ->
        String.to_float(numerator) / String.to_float(denominator)
      [single_value] ->
        String.to_float(single_value)
      _ ->
        1.0  # Default fallback
    end
  end

  defp parse_frame_rate(_), do: 1.0

end
