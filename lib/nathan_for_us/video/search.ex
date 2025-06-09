defmodule NathanForUs.Video.Search do
  @moduledoc """
  Search functionality for video frames and sequences within the Video context.
  
  This module provides business logic for:
  - Frame-based text search across video captions
  - Video filtering and selection management
  - Frame sequence operations for animation
  - Search mode determination and status reporting
  
  ## Examples
  
      # Perform a global search
      {:ok, results} = Video.Search.search_frames("hello", :global, [])
      
      # Filter videos and search within selection
      new_selection = Video.Search.update_video_filter([1, 2], 3)
      {:ok, filtered_results} = Video.Search.search_frames("hello", :filtered, new_selection)
      
      # Get frame sequence for animation
      {:ok, sequence} = Video.Search.get_frame_sequence(frame_id)
      all_indices = Video.Search.get_all_frame_indices(sequence)
  """
  
  alias NathanForUs.Video
  
  @type search_mode :: :global | :filtered
  @type video_result :: %{
    video_id: integer(),
    video_title: String.t(),
    frame_count: integer(),
    frames: list(),
    expanded: boolean()
  }
  @type frame_sequence :: %{
    target_frame: map(),
    sequence_frames: list(),
    sequence_captions: map(),
    target_captions: String.t(),
    sequence_info: map()
  }

  @doc """
  Performs a search across video frames based on the search mode and parameters.
  
  ## Parameters
  
  - `term`: The search query string
  - `search_mode`: Either `:global` (all videos) or `:filtered` (selected videos only)  
  - `selected_video_ids`: List of video IDs to search within (for filtered mode)
  
  ## Returns
  
  - `{:ok, results}`: List of matching frames with metadata
  - `{:error, reason}`: Error message if search fails
  
  ## Examples
  
      # Global search
      {:ok, frames} = search_frames("nathan", :global, [])
      
      # Filtered search within specific videos
      {:ok, frames} = search_frames("business", :filtered, [1, 2, 3])
      
      # Empty search term always returns empty results
      {:ok, []} = search_frames("", :global, [])
  """
  @spec search_frames(String.t(), search_mode(), list(integer())) :: {:ok, list()} | {:error, String.t()}
  def search_frames(term, search_mode, selected_video_ids \\ [])

  def search_frames("", _search_mode, _selected_video_ids) do
    {:ok, []}
  end

  def search_frames(term, :global, _selected_video_ids) do
    try do
      frames = Video.search_frames_by_text_simple(term)
      grouped_results = group_frames_by_video(frames)
      {:ok, grouped_results}
    rescue
      error ->
        {:error, "Search failed: #{Exception.message(error)}"}
    end
  end

  def search_frames(term, :filtered, selected_video_ids) when length(selected_video_ids) > 0 do
    try do
      frames = Video.search_frames_by_text_simple_filtered(term, selected_video_ids)
      grouped_results = group_frames_by_video(frames)
      {:ok, grouped_results}
    rescue
      error ->
        {:error, "Filtered search failed: #{Exception.message(error)}"}
    end
  end

  def search_frames(_term, :filtered, []) do
    {:ok, []}
  end

  @doc """
  Gets frame sequence data for animation display.
  """
  @spec get_frame_sequence(integer()) :: {:ok, frame_sequence()} | {:error, term()}
  def get_frame_sequence(frame_id) do
    case Video.get_frame_sequence(frame_id) do
      {:ok, frame_sequence} ->
        enriched_sequence = enrich_frame_sequence(frame_sequence)
        {:ok, enriched_sequence}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates video filter selection based on current state.
  """
  @spec update_video_filter(list(), integer()) :: list()
  def update_video_filter(current_selected_ids, video_id) do
    if video_id in current_selected_ids do
      List.delete(current_selected_ids, video_id)
    else
      [video_id | current_selected_ids]
    end
  end

  @doc """
  Determines search mode based on selected videos.
  """
  @spec determine_search_mode(list()) :: search_mode()
  def determine_search_mode([]), do: :global
  def determine_search_mode(_selected_video_ids), do: :filtered

  @doc """
  Gets search status information for display.
  """
  @spec get_search_status(search_mode(), list(), list()) :: map()
  def get_search_status(search_mode, selected_video_ids, all_videos) do
    case search_mode do
      :global ->
        %{
          mode: :global,
          message: "Searching across all #{length(all_videos)} videos",
          selected_count: 0,
          total_count: length(all_videos)
        }
      
      :filtered ->
        %{
          mode: :filtered,
          message: "Filtering #{length(selected_video_ids)} of #{length(all_videos)} videos",
          selected_count: length(selected_video_ids),
          total_count: length(all_videos)
        }
    end
  end

  @doc """
  Toggles frame selection for animation sequences.
  """
  @spec toggle_frame_selection(list(), integer()) :: list()
  def toggle_frame_selection(current_selected, frame_index) do
    if frame_index in current_selected do
      List.delete(current_selected, frame_index)
    else
      [frame_index | current_selected] |> Enum.sort()
    end
  end

  @doc """
  Gets all frame indices for selection operations.
  """
  @spec get_all_frame_indices(frame_sequence()) :: list()
  def get_all_frame_indices(%{sequence_frames: frames}) when length(frames) > 0 do
    0..(length(frames) - 1) |> Enum.to_list()
  end
  def get_all_frame_indices(%{sequence_frames: []}), do: []

  @doc """
  Gets autocomplete suggestions based on search term and selected videos.
  """
  @spec get_autocomplete_suggestions(String.t(), search_mode(), list(integer())) :: list(String.t())
  def get_autocomplete_suggestions(search_term, search_mode, selected_video_ids) do
    video_ids = case search_mode do
      :global -> nil
      :filtered -> selected_video_ids
    end
    
    Video.get_autocomplete_suggestions(search_term, video_ids, 5)
  end

  @doc """
  Gets concatenated captions for selected frames.
  """
  @spec get_selected_frames_captions(frame_sequence(), list()) :: String.t()
  def get_selected_frames_captions(frame_sequence, selected_frame_indices) do
    if frame_sequence && Map.has_key?(frame_sequence, :sequence_captions) do
      selected_frames = get_selected_frames(frame_sequence, selected_frame_indices)
      
      all_captions = 
        selected_frames
        |> Enum.flat_map(fn frame ->
          Map.get(frame_sequence.sequence_captions, frame.id, [])
        end)
        |> Enum.uniq()
        |> Enum.reject(&(is_nil(&1) or String.trim(&1) == ""))
      
      case all_captions do
        [] -> "No dialogue found for selected frames"
        captions -> Enum.join(captions, " ")
      end
    else
      "Loading captions..."
    end
  end

  @doc """
  Expands frame sequence backward by adding the previous frame.
  """
  @spec expand_frame_sequence_backward(frame_sequence()) :: {:ok, frame_sequence()} | {:error, term()}
  def expand_frame_sequence_backward(frame_sequence) do
    case Video.expand_frame_sequence_backward(frame_sequence) do
      {:ok, expanded_sequence} ->
        enriched_sequence = enrich_frame_sequence(expanded_sequence)
        {:ok, enriched_sequence}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Expands frame sequence forward by adding the next frame.
  """
  @spec expand_frame_sequence_forward(frame_sequence()) :: {:ok, frame_sequence()} | {:error, term()}
  def expand_frame_sequence_forward(frame_sequence) do
    case Video.expand_frame_sequence_forward(frame_sequence) do
      {:ok, expanded_sequence} ->
        enriched_sequence = enrich_frame_sequence(expanded_sequence)
        {:ok, enriched_sequence}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Groups frames by video for organized display.
  
  Returns a list of video result maps with frames grouped by video.
  All videos start in collapsed state (expanded: false).
  """
  @spec group_frames_by_video(list()) :: list(video_result())
  def group_frames_by_video(frames) do
    frames
    |> Enum.group_by(fn frame -> 
      {Map.get(frame, :video_id), Map.get(frame, :video_title, "Unknown Video")}
    end)
    |> Enum.map(fn {{video_id, video_title}, video_frames} ->
      %{
        video_id: video_id,
        video_title: video_title,
        frame_count: length(video_frames),
        frames: video_frames,
        expanded: false  # All videos start collapsed
      }
    end)
    |> Enum.sort_by(& &1.video_title)
  end

  # Private functions

  defp enrich_frame_sequence(frame_sequence) do
    # Add any additional processing or enrichment of frame sequence data
    # This could include caching, preprocessing, or additional metadata
    frame_sequence
  end

  defp get_selected_frames(frame_sequence, selected_frame_indices) do
    selected_frame_indices
    |> Enum.map(fn index -> 
      Enum.at(frame_sequence.sequence_frames, index)
    end)
    |> Enum.reject(&is_nil/1)
  end
end