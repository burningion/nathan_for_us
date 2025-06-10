defmodule NathanForUs.AdminService do
  @moduledoc """
  Service module providing business logic for administrative operations.
  
  This module handles all admin-related business logic separate from LiveView concerns:
  
  - User access validation and authorization
  - Administrative statistics collection and enrichment
  - Profile backfill operations with validation and error handling
  - Task management and completion processing
  - Parameter parsing and validation
  
  ## Examples
  
      # Validate admin access
      :ok = AdminService.validate_admin_access(user)
      
      # Get enriched statistics
      stats = AdminService.get_admin_stats()
      coverage = AdminService.calculate_profile_coverage(stats)
      
      # Start backfill operation
      options = %{limit: 50, dry_run: true}
      {:ok, task} = AdminService.start_backfill(options)
      
      # Handle completion
      {:ok, results} = AdminService.handle_backfill_completion({:ok, raw_results})
  """
  
  alias NathanForUs.Admin
  
  @type backfill_options :: %{
    limit: integer(),
    dry_run: boolean()
  }
  
  @type backfill_result :: %{
    posts_found: integer(),
    unique_dids: integer(),
    successful: integer(),
    failed: integer(),
    dry_run: boolean()
  }
  
  @type admin_stats :: %{
    total_posts: integer(),
    posts_with_users: integer(),
    posts_without_users: integer(),
    total_users: integer(),
    unique_dids_in_posts: integer()
  }
  
  @doc """
  Validates admin access for a user.
  """
  @spec validate_admin_access(term()) :: :ok | {:error, :access_denied}
  def validate_admin_access(user) do
    if Admin.is_admin?(user) do
      :ok
    else
      {:error, :access_denied}
    end
  end
  
  @doc """
  Gets comprehensive admin statistics.
  """
  @spec get_admin_stats() :: admin_stats()
  def get_admin_stats do
    try do
      stats = Admin.get_stats()
      enrich_stats(stats)
    rescue
      error ->
        %{
          total_posts: 0,
          posts_with_users: 0,
          posts_without_users: 0,
          total_users: 0,
          unique_dids_in_posts: 0,
          error: Exception.message(error)
        }
    end
  end
  
  @doc """
  Validates backfill parameters and starts the operation.
  """
  @spec start_backfill(backfill_options()) :: {:ok, Task.t()} | {:error, String.t()}
  def start_backfill(%{limit: limit, dry_run: dry_run} = options) do
    case validate_backfill_options(options) do
      :ok ->
        task = Task.async(fn ->
          execute_backfill(limit, dry_run)
        end)
        {:ok, task}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Processes backfill task completion.
  """
  @spec handle_backfill_completion(term()) :: {:ok, backfill_result()} | {:error, String.t()}
  def handle_backfill_completion({:ok, results}) do
    enriched_results = enrich_backfill_results(results)
    {:ok, enriched_results}
  end
  
  def handle_backfill_completion({:error, reason}) do
    {:error, format_backfill_error(reason)}
  end
  
  @doc """
  Calculates coverage percentage for profile completion.
  """
  @spec calculate_profile_coverage(admin_stats()) :: float()
  def calculate_profile_coverage(%{total_posts: 0}), do: 0.0
  def calculate_profile_coverage(%{total_posts: total, posts_with_users: with_users}) do
    Float.round(with_users / total * 100, 1)
  end
  
  @doc """
  Validates if a backfill operation can be started.
  """
  @spec can_start_backfill?(boolean()) :: boolean()
  def can_start_backfill?(backfill_running) do
    not backfill_running
  end
  
  @doc """
  Formats backfill options from form parameters.
  """
  @spec parse_backfill_params(map()) :: {:ok, backfill_options()} | {:error, String.t()}
  def parse_backfill_params(%{"limit" => limit_str, "dry_run" => dry_run_str}) do
    try do
      limit = String.to_integer(limit_str)
      dry_run = dry_run_str == "true"
      
      options = %{limit: limit, dry_run: dry_run}
      {:ok, options}
    rescue
      ArgumentError ->
        {:error, "Invalid limit parameter"}
    end
  end
  
  def parse_backfill_params(_params) do
    {:error, "Missing required parameters"}
  end
  
  # Private functions
  
  defp validate_backfill_options(%{limit: limit, dry_run: dry_run}) do
    cond do
      not is_integer(limit) ->
        {:error, "Limit must be an integer"}
      
      limit <= 0 ->
        {:error, "Limit must be greater than 0"}
      
      limit > 1000 ->
        {:error, "Limit cannot exceed 1000"}
      
      not is_boolean(dry_run) ->
        {:error, "Dry run must be true or false"}
      
      true ->
        :ok
    end
  end
  
  defp execute_backfill(limit, dry_run) do
    Admin.backfill_bluesky_profiles(limit: limit, dry_run: dry_run)
  end
  
  defp enrich_stats(stats) do
    Map.merge(stats, %{
      coverage_percentage: calculate_profile_coverage(stats),
      last_updated: DateTime.utc_now()
    })
  end
  
  defp enrich_backfill_results(results) do
    Map.merge(results, %{
      completion_rate: calculate_completion_rate(results),
      timestamp: DateTime.utc_now()
    })
  end
  
  defp calculate_completion_rate(%{successful: successful, failed: failed}) 
       when successful + failed > 0 do
    Float.round(successful / (successful + failed) * 100, 1)
  end
  
  defp calculate_completion_rate(_), do: 0.0
  
  defp format_backfill_error(reason) do
    case reason do
      {:timeout, _} -> "Backfill operation timed out"
      :killed -> "Backfill operation was terminated"
      _ -> "Backfill failed: #{inspect(reason)}"
    end
  end

  @doc """
  Generates usernames for all users without usernames based on their email.
  """
  @spec generate_usernames_from_emails() :: {:ok, integer()} | {:error, String.t()}
  def generate_usernames_from_emails do
    try do
      result = Admin.generate_usernames_from_emails()
      {:ok, result}
    rescue
      error ->
        {:error, Exception.message(error)}
    end
  end

  @doc """
  Tests if FFMPEG is available and accessible in the system PATH.
  """
  @spec test_ffmpeg_availability() :: {:ok, String.t()} | {:error, String.t()}
  def test_ffmpeg_availability do
    try do
      case System.cmd("which", ["ffmpeg"]) do
        {path, 0} ->
          path = String.trim(path)
          case System.cmd("ffmpeg", ["-version"]) do
            {version_output, 0} ->
              # Extract version from first line
              version_line = version_output |> String.split("\n") |> List.first()
              {:ok, "FFMPEG found at #{path}. #{version_line}"}
            
            {error_output, _exit_code} ->
              {:error, "FFMPEG found at #{path} but failed to get version: #{error_output}"}
          end
        
        {_output, _exit_code} ->
          {:error, "FFMPEG not found in system PATH"}
      end
    rescue
      error ->
        {:error, "Error testing FFMPEG: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generates a GIF from selected frame sequence using FFMPEG.
  
  Takes a frame sequence and selected frame indices, extracts the frames
  in order, and creates an animated GIF with appropriate framerate based
  on the source video's timing.
  """
  @spec generate_gif_from_frames(map(), list()) :: {:ok, binary()} | {:error, String.t()}
  def generate_gif_from_frames(frame_sequence, selected_frame_indices) do
    try do
      # Validate inputs
      if Enum.empty?(selected_frame_indices) do
        {:error, "No frames selected for GIF generation"}
      else
        # Create temporary directory for frame processing
        temp_dir = System.tmp_dir!() |> Path.join("gif_generation_#{:os.system_time(:millisecond)}")
        File.mkdir_p!(temp_dir)

        try do
          # Extract selected frames and write to temp files
          frame_paths = extract_selected_frames_to_temp(frame_sequence, selected_frame_indices, temp_dir)
          
          # Calculate framerate from video metadata or timestamps
          framerate = calculate_gif_framerate(frame_sequence, selected_frame_indices)
          
          # Generate GIF using FFMPEG
          generate_gif_with_ffmpeg(frame_paths, framerate, temp_dir)
        after
          # Clean up temp directory
          File.rm_rf(temp_dir)
        end
      end
    rescue
      error ->
        {:error, "GIF generation failed: #{Exception.message(error)}"}
    end
  end

  # Private helper functions for GIF generation

  defp extract_selected_frames_to_temp(frame_sequence, selected_frame_indices, temp_dir) do
    selected_frame_indices
    |> Enum.sort()
    |> Enum.with_index()
    |> Enum.map(fn {frame_index, output_index} ->
      frame = Enum.at(frame_sequence.sequence_frames, frame_index)
      
      if frame && frame.image_data do
        # Decode image data and write to temp file
        output_path = Path.join(temp_dir, "frame_#{String.pad_leading(to_string(output_index), 4, "0")}.jpg")
        
        image_binary = decode_frame_image_data(frame.image_data)
        File.write!(output_path, image_binary)
        
        output_path
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp decode_frame_image_data(hex_data) when is_binary(hex_data) do
    # The image data is stored as hex-encoded string starting with \x
    case String.starts_with?(hex_data, "\\x") do
      true ->
        # Remove the \x prefix and decode from hex
        hex_string = String.slice(hex_data, 2..-1//1)
        case Base.decode16(hex_string, case: :lower) do
          {:ok, binary_data} -> binary_data
          :error -> <<>>
        end
      false ->
        # Already binary data
        hex_data
    end
  end

  defp calculate_gif_framerate(frame_sequence, selected_frame_indices) do
    # Use the actual timestamp differences to maintain real-life timing
    calculate_framerate_from_timestamps(frame_sequence, selected_frame_indices)
  end

  defp get_video_fps(frame_sequence) do
    # Try to get FPS from the video record
    case Map.get(frame_sequence, :video) do
      %{fps: fps} when is_number(fps) -> fps
      _ -> nil
    end
  end

  defp calculate_framerate_from_timestamps(frame_sequence, selected_frame_indices) do
    if length(selected_frame_indices) < 2 do
      # Single frame gets reasonable default
      4.0
    else
      selected_frames = selected_frame_indices
        |> Enum.sort()
        |> Enum.map(&Enum.at(frame_sequence.sequence_frames, &1))
        |> Enum.reject(&is_nil/1)
      
      if length(selected_frames) >= 2 do
        # Calculate average time difference between frames
        timestamps = Enum.map(selected_frames, &Map.get(&1, :timestamp_ms, 0))
        
        time_diffs = timestamps
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [t1, t2] -> t2 - t1 end)
          |> Enum.reject(& &1 <= 0)
        
        if Enum.empty?(time_diffs) do
          4.0  # Default fallback
        else
          avg_diff_ms = Enum.sum(time_diffs) / length(time_diffs)
          
          # Since frames are extracted at 1fps (1000ms intervals) from 30fps source,
          # we need to play them faster to feel natural
          # Think of it as "key moments" that should flow smoothly
          cond do
            avg_diff_ms >= 1000 ->
              # 1-second extracted intervals: play at 4-6 fps for smooth flow
              5.0
            
            avg_diff_ms >= 500 ->
              # 0.5-second intervals: play at 3-4 fps
              4.0
            
            avg_diff_ms >= 200 ->
              # Faster extractions: moderate speed
              3.0
            
            true ->
              # Very fast extractions: calculate normally
              fps = 1000.0 / avg_diff_ms
              min(max(fps, 2.0), 8.0)
          end
        end
      else
        4.0  # Default fallback
      end
    end
  end

  defp generate_gif_with_ffmpeg(frame_paths, framerate, temp_dir) do
    if Enum.empty?(frame_paths) do
      {:error, "No valid frames to process"}
    else
      output_path = Path.join(temp_dir, "output.gif")
      palette_path = Path.join(temp_dir, "palette.png")
      input_pattern = Path.join(temp_dir, "frame_%04d.jpg")
      
      # Step 1: Generate optimized palette
      palette_args = [
        "-y",  # Overwrite output file
        "-framerate", Float.to_string(framerate),
        "-i", input_pattern,
        "-vf", "scale=640:-1:flags=lanczos,palettegen=max_colors=256:reserve_transparent=0",
        palette_path
      ]
      
      case System.cmd("ffmpeg", palette_args, stderr_to_stdout: true) do
        {_palette_output, 0} ->
          # Step 2: Create GIF using the generated palette
          gif_args = [
            "-y",  # Overwrite output file
            "-framerate", Float.to_string(framerate),
            "-i", input_pattern,
            "-i", palette_path,
            "-lavfi", "scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5",
            "-r", Float.to_string(framerate),
            output_path
          ]
          
          case System.cmd("ffmpeg", gif_args, stderr_to_stdout: true) do
            {_gif_output, 0} ->
              # Read the generated GIF file
              case File.read(output_path) do
                {:ok, gif_data} ->
                  {:ok, gif_data}
                {:error, reason} ->
                  {:error, "Failed to read generated GIF: #{reason}"}
              end
            
            {error_output, exit_code} ->
              {:error, "GIF creation failed (exit code #{exit_code}): #{error_output}"}
          end
        
        {error_output, exit_code} ->
          {:error, "Palette generation failed (exit code #{exit_code}): #{error_output}"}
      end
    end
  end
end