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

      {:error, reason} ->
        {:error, reason}
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
    
    System.cmd("ffmpeg", cmd, stderr_to_stdout: true)
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
end