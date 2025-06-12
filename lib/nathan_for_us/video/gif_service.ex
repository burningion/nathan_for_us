defmodule NathanForUs.Video.GifService do
  @moduledoc """
  Service for generating and caching GIFs from video frame selections.

  This module provides the main interface for GIF operations including:
  - Cache lookup and storage
  - GIF generation from frame selections
  - Integration with video search URLs
  """

  alias NathanForUs.Video.GifCache
  alias NathanForUs.Video
  alias NathanForUs.AdminService
  require Logger

  @doc """
  Gets or generates a GIF for the given video_id and frame_ids.

  First checks the cache, and if not found, generates a new GIF and stores it.
  Returns the GIF binary data.
  """
  def get_or_generate_gif(video_id, frame_ids) when is_integer(video_id) and is_list(frame_ids) do
    # First try to get from cache
    case GifCache.lookup_cache(video_id, frame_ids) do
      %GifCache{gif_data: gif_data} when not is_nil(gif_data) ->
        Logger.info("GIF cache hit for video_id=#{video_id}, frame_ids=#{inspect(frame_ids)}")
        {:ok, gif_data}

      nil ->
        Logger.info("GIF cache miss for video_id=#{video_id}, frame_ids=#{inspect(frame_ids)}")
        generate_and_cache_gif(video_id, frame_ids)
    end
  end

  @doc """
  Generates a GIF from URL parameters and optionally caches it.

  Expects URL parameters like: frame=3062&frame_ids=3062,3063,3064,3065,3066,3067,3068,3069,3070,3071,3072
  """
  def generate_gif_from_url_params(params) do
    case parse_gif_params(params) do
      {:ok, video_id, frame_ids} ->
        get_or_generate_gif(video_id, frame_ids)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parses URL parameters to extract video_id and frame_ids for GIF generation.

  ## Expected URL format:
  /video-search?frame=3062&frame_ids=3062,3063,3064,3065,3066,3067,3068,3069,3070,3071,3072
  """
  def parse_gif_params(params) do
    with {:ok, base_frame_id} <- parse_frame_param(params),
         {:ok, frame_ids} <- parse_frame_ids_param(params),
         {:ok, video_id} <- get_video_id_from_frame(base_frame_id) do
      {:ok, video_id, frame_ids}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks if the current URL parameters indicate a GIF should be generated.

  Returns true if both frame and frame_ids parameters are present.
  """
  def should_generate_gif?(params) do
    Map.has_key?(params, "frame") && Map.has_key?(params, "frame_ids")
  end

  # Private functions

  defp generate_and_cache_gif(video_id, frame_ids) do
    # Get the first frame ID to build the frame sequence
    base_frame_id = List.first(frame_ids)

    case Video.get_frame_sequence_from_frame_ids(base_frame_id, frame_ids) do
      {:ok, frame_sequence} ->
        # Generate indices for all frames (they should all be selected)
        selected_indices = 0..(length(frame_sequence.sequence_frames) - 1) |> Enum.to_list()

        case AdminService.generate_gif_from_frames(frame_sequence, selected_indices) do
          {:ok, gif_data} ->
            # Store in cache
            cache_result =
              GifCache.store_cache(video_id, frame_ids, gif_data, %{
                duration_ms: calculate_gif_duration(frame_sequence, selected_indices),
                frame_count: length(frame_ids)
              })

            case cache_result do
              {:ok, _cached_gif} ->
                Logger.info("GIF generated and cached successfully for video_id=#{video_id}")

              {:error, reason} ->
                Logger.warning("GIF generated but caching failed: #{reason}")
            end

            {:ok, gif_data}

          {:error, reason} ->
            Logger.error("GIF generation failed for video_id=#{video_id}: #{reason}")
            {:error, "Failed to generate GIF: #{reason}"}
        end

      {:error, reason} ->
        Logger.error("Failed to get frame sequence for video_id=#{video_id}: #{reason}")
        {:error, "Failed to load frame sequence: #{reason}"}
    end
  end

  defp parse_frame_param(params) do
    case Map.get(params, "frame") do
      nil ->
        {:error, "Missing frame parameter"}

      frame_str ->
        try do
          frame_id = String.to_integer(frame_str)
          {:ok, frame_id}
        rescue
          ArgumentError -> {:error, "Invalid frame parameter"}
        end
    end
  end

  defp parse_frame_ids_param(params) do
    case Map.get(params, "frame_ids") do
      nil ->
        {:error, "Missing frame_ids parameter"}

      "" ->
        {:error, "Empty frame_ids parameter"}

      frame_ids_str ->
        try do
          frame_ids =
            frame_ids_str
            |> String.split(",")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))
            |> Enum.map(&String.to_integer/1)

          if Enum.empty?(frame_ids) do
            {:error, "No valid frame IDs found"}
          else
            {:ok, frame_ids}
          end
        rescue
          ArgumentError -> {:error, "Invalid frame_ids parameter"}
        end
    end
  end

  defp get_video_id_from_frame(frame_id) do
    case Video.get_video_frame(frame_id) do
      {:ok, frame} -> {:ok, frame.video_id}
      {:error, _} -> {:error, "Frame not found"}
    end
  end

  defp calculate_gif_duration(frame_sequence, selected_indices) do
    if length(selected_indices) >= 2 do
      selected_frames =
        selected_indices
        |> Enum.map(&Enum.at(frame_sequence.sequence_frames, &1))
        |> Enum.reject(&is_nil/1)

      case {List.first(selected_frames), List.last(selected_frames)} do
        {%{timestamp_ms: first_ts}, %{timestamp_ms: last_ts}} ->
          last_ts - first_ts

        _ ->
          nil
      end
    else
      nil
    end
  end
end
