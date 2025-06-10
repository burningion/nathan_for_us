defmodule NathanForUsWeb.VideoSearchLive do
  @moduledoc """
  LiveView for searching video frames by text content in captions.
  
  Allows users to search for text across all video captions and displays
  matching frames as images loaded directly from the database.
  """
  
  use NathanForUsWeb, :live_view
  
  alias NathanForUs.{Video}
  alias NathanForUs.Video.Search
  alias NathanForUsWeb.Components.VideoSearch.{
    SearchHeader,
    SearchInterface,
    SearchResults,
    VideoFilter,
    FrameSequence
  }

  on_mount {__MODULE__, :assign_meta_tags}

  def on_mount(:assign_meta_tags, _params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Nathan Appearance Video Search")
      |> assign(:page_description, "search a quote and find the frame(s) in which nathan said it in an interview")
    
    {:cont, socket}
  end

  @impl true
  def mount(_params, session, socket) do
    videos = Video.list_videos()

    search_form = %{"term" => ""}
    
    # Show welcome modal if explicitly set in session (for new users)
    show_welcome_modal = Map.get(session, "show_welcome_modal", false)
    
    socket =
      socket
      |> assign(:search_form, search_form)
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:loading, false)
      |> assign(:videos, videos)
      |> assign(:show_video_modal, false)
      |> assign(:selected_video_ids, [])
      |> assign(:search_mode, :global)
      |> assign(:show_sequence_modal, false)
      |> assign(:frame_sequence, nil)
      |> assign(:selected_frame_indices, [])
      |> assign(:autocomplete_suggestions, [])
      |> assign(:show_autocomplete, false)
      |> assign(:expanded_videos, MapSet.new())  # Track which videos are expanded
      |> assign(:frame_sequence_version, 0)
      |> assign(:show_welcome_modal, show_welcome_modal)
      |> assign(:gif_generation_status, nil)
      |> assign(:generated_gif_data, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Only handle URL params if we don't already have a frame sequence open
    # This prevents URL updates from overriding expanded sequences
    socket = 
      socket
      |> assign(:current_params, params)
      |> handle_video_selection_from_params(params)
    
    socket = 
      if socket.assigns.show_sequence_modal do
        # Don't override existing frame sequence if modal is already open
        socket
      else
        handle_frame_selection_from_params(socket, params)
      end
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"term" => term}}, socket) when term != "" do
    send(self(), {:perform_search, term})
    
    socket =
      socket
      |> assign(:search_term, term)
      |> assign(:loading, true)
      |> assign(:search_results, [])

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => %{"term" => ""}}, socket) do
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:loading, false)

    {:noreply, socket}
  end

  def handle_event("search", %{"search[term]" => term}, socket) when term != "" do
    send(self(), {:perform_search, term})
    
    socket =
      socket
      |> assign(:search_term, term)
      |> assign(:loading, true)
      |> assign(:search_results, [])

    {:noreply, socket}
  end

  def handle_event("search", %{"search[term]" => ""}, socket) do
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:loading, false)

    {:noreply, socket}
  end
  
  # Catch-all for any other search patterns to handle gracefully
  def handle_event("search", params, socket) do
    # Extract term from various possible parameter structures
    term = case params do
      %{"term" => term} -> term
      %{"search_term" => term} -> term
      _ -> ""
    end
    
    if term != "" do
      send(self(), {:perform_search, term})
      
      socket =
        socket
        |> assign(:search_term, term)
        |> assign(:loading, true)
        |> assign(:search_results, [])

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:search_term, "")
        |> assign(:search_results, [])
        |> assign(:loading, false)

      {:noreply, socket}
    end
  end

  def handle_event("toggle_video_modal", _params, socket) do
    {:noreply, assign(socket, :show_video_modal, !socket.assigns.show_video_modal)}
  end

  def handle_event("toggle_video_selection", %{"video_id" => video_id}, socket) do
    try do
      video_id = String.to_integer(video_id)
      current_selected = socket.assigns.selected_video_ids
      
      new_selected_ids = Search.update_video_filter(current_selected, video_id)

      socket = 
        socket
        |> assign(:selected_video_ids, new_selected_ids)
        |> push_video_selection_to_url()

      {:noreply, socket}
    rescue
      ArgumentError ->
        socket = put_flash(socket, :error, "Invalid video ID")
        {:noreply, socket}
    end
  end

  def handle_event("apply_video_filter", _params, socket) do
    search_mode = Search.determine_search_mode(socket.assigns.selected_video_ids)
    
    socket =
      socket
      |> assign(:search_mode, search_mode)
      |> assign(:show_video_modal, false)
      |> assign(:search_results, [])

    {:noreply, socket}
  end

  def handle_event("clear_video_filter", _params, socket) do
    socket =
      socket
      |> assign(:selected_video_ids, [])
      |> assign(:search_mode, :global)
      |> assign(:search_results, [])
      |> push_video_selection_to_url()

    {:noreply, socket}
  end

  def handle_event("select_all_videos", _params, socket) do
    all_video_ids = Enum.map(socket.assigns.videos, & &1.id)
    search_mode = Search.determine_search_mode(all_video_ids)
    
    socket =
      socket
      |> assign(:selected_video_ids, all_video_ids)
      |> assign(:search_mode, search_mode)

    {:noreply, socket}
  end

  def handle_event("clear_video_selection", _params, socket) do
    socket =
      socket
      |> assign(:selected_video_ids, [])
      |> assign(:search_mode, :global)

    {:noreply, socket}
  end

  def handle_event("process_video", %{"video_path" => video_path}, socket) do
    try do
      case NathanForUs.VideoProcessing.process_video(video_path) do
        {:ok, video} ->
          socket =
            socket
            |> put_flash(:info, "Video '#{video.title}' queued for processing")
            |> assign(:videos, Video.list_videos())

          {:noreply, socket}
          
        {:error, _changeset} ->
          socket = put_flash(socket, :error, "Failed to queue video for processing")
          {:noreply, socket}
      end
    rescue
      ArgumentError ->
        # Video processing is disabled (e.g., in test environment)
        socket = put_flash(socket, :error, "Video processing is currently unavailable")
        {:noreply, socket}
    end
  end

  def handle_event("show_frame_sequence", %{"frame_id" => frame_id}, socket) do
    try do
      frame_id = String.to_integer(frame_id)
      
      case Video.get_frame_sequence(frame_id) do
        {:ok, frame_sequence} ->
          # Select all frames by default
          all_frame_indices = 0..(length(frame_sequence.sequence_frames) - 1) |> Enum.to_list()
          
          socket =
            socket
            |> assign(:frame_sequence, frame_sequence)
            |> assign(:show_sequence_modal, true)
            |> assign(:selected_frame_indices, all_frame_indices)
            |> push_frame_selection_to_url()
          
          {:noreply, socket}
        
        {:error, _reason} ->
          socket = put_flash(socket, :error, "Could not load frame sequence")
          {:noreply, socket}
      end
    rescue
      ArgumentError ->
        socket = put_flash(socket, :error, "Invalid frame ID")
        {:noreply, socket}
    end
  end

  def handle_event("close_sequence_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_sequence_modal, false)
      |> assign(:frame_sequence, nil)
      |> assign(:selected_frame_indices, [])
      |> assign(:gif_generation_status, nil)
      |> assign(:generated_gif_data, nil)
      |> push_frame_selection_to_url()
    
    {:noreply, socket}
  end

  def handle_event("toggle_frame_selection", %{"frame_index" => frame_index_str}, socket) do
    try do
      frame_index = String.to_integer(frame_index_str)
      current_selected = socket.assigns.selected_frame_indices
      
      new_selected = 
        if frame_index in current_selected do
          List.delete(current_selected, frame_index)
        else
          [frame_index | current_selected] |> Enum.sort()
        end
      
      socket = 
        socket
        |> assign(:selected_frame_indices, new_selected)
        |> push_frame_selection_to_url()
      
      {:noreply, socket}
    rescue
      ArgumentError ->
        socket = put_flash(socket, :error, "Invalid frame index")
        {:noreply, socket}
    end
  end

  def handle_event("select_all_frames", _params, socket) do
    all_frame_indices = 0..(length(socket.assigns.frame_sequence.sequence_frames) - 1) |> Enum.to_list()
    socket = 
      socket
      |> assign(:selected_frame_indices, all_frame_indices)
      |> push_frame_selection_to_url()
    
    {:noreply, socket}
  end

  def handle_event("deselect_all_frames", _params, socket) do
    socket = 
      socket
      |> assign(:selected_frame_indices, [])
      |> push_frame_selection_to_url()
    
    {:noreply, socket}
  end

  def handle_event("expand_sequence_backward", _params, socket) do
    require Logger
    Logger.info("Expand sequence backward clicked")
    
    case socket.assigns.frame_sequence do
      nil -> 
        Logger.info("No frame sequence found")
        {:noreply, socket}
      frame_sequence ->
        Logger.info("Current sequence: #{frame_sequence.sequence_info.start_frame_number}-#{frame_sequence.sequence_info.end_frame_number}")
        
        # Get one frame before the current sequence start
        case Search.expand_frame_sequence_backward(frame_sequence) do
          {:ok, expanded_sequence} ->
            Logger.info("Expanded sequence: #{expanded_sequence.sequence_info.start_frame_number}-#{expanded_sequence.sequence_info.end_frame_number}")
            
            # Update selected indices to account for the new frame at the beginning
            # and automatically select the new frame (index 0)
            updated_indices = [0 | Enum.map(socket.assigns.selected_frame_indices, fn index -> index + 1 end)]
            Logger.info("Updated selected indices with new frame: #{inspect(updated_indices)}")
            
            socket =
              socket
              |> assign(:frame_sequence, expanded_sequence)
              |> assign(:selected_frame_indices, updated_indices)
              |> assign(:frame_sequence_version, socket.assigns.frame_sequence_version + 1)
              |> push_frame_selection_to_url()
            
            {:noreply, socket}
          
          {:error, reason} ->
            Logger.info("Expand backward failed: #{inspect(reason)}")
            {:noreply, socket}
        end
    end
  end

  def handle_event("expand_sequence_forward", _params, socket) do
    require Logger
    Logger.info("Expand sequence forward clicked")
    
    case socket.assigns.frame_sequence do
      nil -> 
        Logger.info("No frame sequence found")
        {:noreply, socket}
      frame_sequence ->
        Logger.info("Current sequence: #{frame_sequence.sequence_info.start_frame_number}-#{frame_sequence.sequence_info.end_frame_number}")
        
        # Get one frame after the current sequence end
        case Search.expand_frame_sequence_forward(frame_sequence) do
          {:ok, expanded_sequence} ->
            Logger.info("Expanded sequence: #{expanded_sequence.sequence_info.start_frame_number}-#{expanded_sequence.sequence_info.end_frame_number}")
            
            # Selected indices stay the same since we're adding at the end
            # but also automatically select the new frame (last index)
            new_frame_index = length(expanded_sequence.sequence_frames) - 1
            updated_indices = socket.assigns.selected_frame_indices ++ [new_frame_index]
            
            socket = 
              socket
              |> assign(:frame_sequence, expanded_sequence)
              |> assign(:selected_frame_indices, updated_indices)
              |> assign(:frame_sequence_version, socket.assigns.frame_sequence_version + 1)
              |> push_frame_selection_to_url()
            
            {:noreply, socket}
          
          {:error, reason} ->
            Logger.info("Expand forward failed: #{inspect(reason)}")
            {:noreply, socket}
        end
    end
  end

  def handle_event("expand_sequence_backward_multiple", params, socket) do
    require Logger
    Logger.info("Received expand_sequence_backward_multiple event with params: #{inspect(params)}")
    
    count_str = Map.get(params, "value", "")
    Logger.info("Extracted count_str: #{inspect(count_str)}")
    
    case {socket.assigns.frame_sequence, count_str} do
      {nil, _} -> 
        Logger.info("No frame sequence available")
        {:noreply, socket}
      
      {_, ""} ->
        Logger.info("Empty value provided")
        {:noreply, socket}
      
      {frame_sequence, count_str} ->
        try do
          count = String.to_integer(count_str)
          Logger.info("Parsed count: #{count}")
          
          case count do
            c when c >= 1 and c <= 20 ->
              Logger.info("Expanding backward by #{count} frames")
              Logger.info("Current sequence frames: #{length(frame_sequence.sequence_frames)}")
              Logger.info("Current start frame: #{frame_sequence.sequence_info.start_frame_number}")
              Logger.info("Current end frame: #{frame_sequence.sequence_info.end_frame_number}")
              
              # Expand backward multiple times
              {final_sequence, total_added} = expand_backward_multiple(frame_sequence, count, 0)
              Logger.info("Final sequence frames: #{length(final_sequence.sequence_frames)}, added: #{total_added}")
              Logger.info("Final start frame: #{final_sequence.sequence_info.start_frame_number}")
              Logger.info("Final end frame: #{final_sequence.sequence_info.end_frame_number}")
              
              if total_added > 0 do
                # Add new indices for all added frames (they'll be at indices 0 to total_added-1)
                new_indices = Enum.to_list(0..(total_added-1))
                # Shift existing indices by total_added
                shifted_existing = Enum.map(socket.assigns.selected_frame_indices, &(&1 + total_added))
                updated_indices = (new_indices ++ shifted_existing) |> Enum.uniq() |> Enum.sort()
                
                socket =
                  socket
                  |> assign(:frame_sequence, final_sequence)
                  |> assign(:selected_frame_indices, updated_indices)
                  |> assign(:frame_sequence_version, socket.assigns.frame_sequence_version + 1)
                  |> push_frame_selection_to_url()
                  |> push_event("clear_expand_form", %{target: "expand-backward-form"})
                
                {:noreply, socket}
              else
                Logger.info("No frames were added")
                {:noreply, socket}
              end
            
            _ ->
              Logger.info("Invalid count: #{count}")
              {:noreply, socket}
          end
        rescue
          ArgumentError ->
            Logger.info("Failed to parse count_str: #{inspect(count_str)}")
            {:noreply, socket}
        end
    end
  end

  def handle_event("expand_sequence_forward_multiple", params, socket) do
    require Logger
    Logger.info("Received expand_sequence_forward_multiple event with params: #{inspect(params)}")
    
    count_str = Map.get(params, "value", "")
    Logger.info("Extracted count_str: #{inspect(count_str)}")
    
    case {socket.assigns.frame_sequence, count_str} do
      {nil, _} -> 
        Logger.info("No frame sequence available")
        {:noreply, socket}
      
      {_, ""} ->
        Logger.info("Empty value provided")
        {:noreply, socket}
      
      {frame_sequence, count_str} ->
        try do
          count = String.to_integer(count_str)
          Logger.info("Parsed count: #{count}")
          
          case count do
            c when c >= 1 and c <= 20 ->
              Logger.info("Expanding forward by #{count} frames")
              Logger.info("Current sequence frames: #{length(frame_sequence.sequence_frames)}")
              Logger.info("Current start frame: #{frame_sequence.sequence_info.start_frame_number}")
              Logger.info("Current end frame: #{frame_sequence.sequence_info.end_frame_number}")
              
              # Expand forward multiple times
              {final_sequence, total_added} = expand_forward_multiple(frame_sequence, count, 0)
              Logger.info("Final sequence frames: #{length(final_sequence.sequence_frames)}, added: #{total_added}")
              Logger.info("Final start frame: #{final_sequence.sequence_info.start_frame_number}")
              Logger.info("Final end frame: #{final_sequence.sequence_info.end_frame_number}")
              
              if total_added > 0 do
                # Add new indices for all added frames (they'll be at the end)
                original_length = length(socket.assigns.frame_sequence.sequence_frames)
                new_indices = Enum.to_list(original_length..(original_length + total_added - 1))
                updated_indices = (socket.assigns.selected_frame_indices ++ new_indices) |> Enum.uniq() |> Enum.sort()
                
                socket =
                  socket
                  |> assign(:frame_sequence, final_sequence)
                  |> assign(:selected_frame_indices, updated_indices)
                  |> assign(:frame_sequence_version, socket.assigns.frame_sequence_version + 1)
                  |> push_frame_selection_to_url()
                  |> push_event("clear_expand_form", %{target: "expand-forward-form"})
                
                {:noreply, socket}
              else
                Logger.info("No frames were added")
                {:noreply, socket}
              end
            
            _ ->
              Logger.info("Invalid count: #{count}")
              {:noreply, socket}
          end
        rescue
          ArgumentError ->
            Logger.info("Failed to parse count_str: #{inspect(count_str)}")
            {:noreply, socket}
        end
    end
  end

  def handle_event("autocomplete_search", %{"search" => %{"term" => term}}, socket) do
    search_form = %{"term" => term}
    
    if String.length(term) >= 3 do
      suggestions = Search.get_autocomplete_suggestions(term, socket.assigns.search_mode, socket.assigns.selected_video_ids)
      
      socket =
        socket
        |> assign(:search_form, search_form)
        |> assign(:search_term, term)
        |> assign(:autocomplete_suggestions, suggestions)
        |> assign(:show_autocomplete, true)
      
      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:search_form, search_form)
        |> assign(:search_term, term)
        |> assign(:autocomplete_suggestions, [])
        |> assign(:show_autocomplete, false)
      
      {:noreply, socket}
    end
  end

  def handle_event("select_suggestion", %{"suggestion" => suggestion}, socket) do
    # Only populate the search field, don't trigger search
    search_form = %{"term" => suggestion}
    
    socket =
      socket
      |> assign(:search_form, search_form)
      |> assign(:search_term, suggestion)
      |> assign(:show_autocomplete, false)
      |> assign(:autocomplete_suggestions, [])

    {:noreply, socket}
  end

  def handle_event("hide_autocomplete", _params, socket) do
    socket = assign(socket, :show_autocomplete, false)
    {:noreply, socket}
  end

  def handle_event("close_welcome_modal", _params, socket) do
    {:noreply, assign(socket, :show_welcome_modal, false)}
  end

  def handle_event("show_welcome_for_first_visit", _params, socket) do
    # Client-side determined this is a first visit, show the modal
    {:noreply, assign(socket, :show_welcome_modal, true)}
  end

  def handle_event("ignore", _params, socket) do
    # Ignore events (e.g. from animation speed slider)
    {:noreply, socket}
  end

  def handle_event("generate_gif", _params, socket) do
    case {socket.assigns.frame_sequence, socket.assigns.selected_frame_indices} do
      {frame_sequence, selected_indices} when not is_nil(frame_sequence) and length(selected_indices) > 0 ->
        # Start async GIF generation
        task = Task.async(fn ->
          NathanForUs.AdminService.generate_gif_from_frames(frame_sequence, selected_indices)
        end)
        
        socket = 
          socket
          |> assign(:gif_generation_status, :generating)
          |> assign(:gif_generation_task, task)
          |> assign(:generated_gif_data, nil)
        
        {:noreply, socket}
      
      {nil, _} ->
        socket = put_flash(socket, :error, "No frame sequence available")
        {:noreply, socket}
      
      {_, []} ->
        socket = put_flash(socket, :error, "No frames selected for GIF generation")
        {:noreply, socket}
    end
  end

  def handle_event("toggle_video_expansion", %{"video_id" => video_id_str}, socket) do
    try do
      video_id = String.to_integer(video_id_str)
      expanded_videos = socket.assigns.expanded_videos
      
      updated_expanded = 
        if MapSet.member?(expanded_videos, video_id) do
          MapSet.delete(expanded_videos, video_id)
        else
          MapSet.put(expanded_videos, video_id)
        end
      
      # Update the search results to reflect the new expanded state
      updated_results = update_video_expansion_state(socket.assigns.search_results, updated_expanded)
      
      socket =
        socket
        |> assign(:expanded_videos, updated_expanded)
        |> assign(:search_results, updated_results)
      
      {:noreply, socket}
    rescue
      ArgumentError ->
        socket = put_flash(socket, :error, "Invalid video ID")
        {:noreply, socket}
    end
  end

  # Helper function to update expansion state in search results
  defp update_video_expansion_state(search_results, expanded_videos) do
    Enum.map(search_results, fn video_result ->
      Map.put(video_result, :expanded, MapSet.member?(expanded_videos, video_result.video_id))
    end)
  end

  # Handle video selection from URL parameters
  defp handle_video_selection_from_params(socket, params) do
    case Map.get(params, "video") do
      nil -> socket
      video_id_str ->
        try do
          video_id = String.to_integer(video_id_str)
          
          # Validate video exists
          if Enum.find(socket.assigns.videos, &(&1.id == video_id)) do
            socket
            |> assign(:selected_video_ids, [video_id])
            |> assign(:search_mode, :filtered)
          else
            socket
          end
        rescue
          ArgumentError -> socket
        end
    end
  end

  # Handle frame selection from URL parameters
  defp handle_frame_selection_from_params(socket, params) do
    case Map.get(params, "frame") do
      nil -> socket
      frame_id_str ->
        try do
          frame_id = String.to_integer(frame_id_str)
          
          # Parse selected frames from URL first
          selected_indices = parse_selected_frames_from_params(params)
          
          # Use the new function that ensures all selected frames are loaded
          frame_sequence_result = if Enum.empty?(selected_indices) do
            Video.get_frame_sequence(frame_id)
          else
            Video.get_frame_sequence_with_selected_indices(frame_id, selected_indices)
          end
          
          case frame_sequence_result do
            {:ok, frame_sequence} ->
              # If no specific frames selected, select all frames by default
              final_selected_indices = if Enum.empty?(selected_indices) do
                0..(length(frame_sequence.sequence_frames) - 1) |> Enum.to_list()
              else
                selected_indices
              end
              
              socket
              |> assign(:frame_sequence, frame_sequence)
              |> assign(:show_sequence_modal, true)
              |> assign(:selected_frame_indices, final_selected_indices)
            
            {:error, _reason} ->
              socket
          end
        rescue
          ArgumentError -> socket
        end
    end
  end

  # Parse selected frame indices from URL parameters
  defp parse_selected_frames_from_params(params) do
    case Map.get(params, "frames") do
      nil -> []
      "" -> []  # Handle empty string
      frames_str ->
        frames_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))  # Reject empty strings
        |> Enum.reduce([], fn frame_str, acc ->
          try do
            frame_index = String.to_integer(frame_str)
            [frame_index | acc]
          rescue
            ArgumentError -> acc
          end
        end)
        |> Enum.uniq()  # Remove duplicates
        |> Enum.sort()
    end
  end

  # Update URL with current video selection
  defp push_video_selection_to_url(socket) do
    current_params = get_current_url_params(socket)
    
    new_params = case socket.assigns.selected_video_ids do
      [] -> Map.delete(current_params, "video")
      [video_id] -> Map.put(current_params, "video", to_string(video_id))
      _ -> current_params # Multiple videos not supported in URL yet
    end
    
    push_patch(socket, to: build_url_with_params("/video-search", new_params))
  end

  # Update URL with current frame selection
  defp push_frame_selection_to_url(socket) do
    current_params = get_current_url_params(socket)
    
    new_params = case {socket.assigns.frame_sequence, socket.assigns.selected_frame_indices} do
      {nil, _} -> 
        current_params
        |> Map.delete("frame")
        |> Map.delete("frames")
      
      {frame_sequence, []} ->
        current_params
        |> Map.put("frame", to_string(frame_sequence.target_frame.id))
        |> Map.delete("frames")
      
      {frame_sequence, selected_indices} ->
        frames_str = selected_indices |> Enum.sort() |> Enum.join(",")
        current_params
        |> Map.put("frame", to_string(frame_sequence.target_frame.id))
        |> Map.put("frames", frames_str)
    end
    
    push_patch(socket, to: build_url_with_params("/video-search", new_params))
  end

  # Get current URL parameters
  defp get_current_url_params(socket) do
    # Extract current URL parameters from socket context
    socket.assigns[:current_params] || %{}
  end

  # Build URL with parameters
  defp build_url_with_params(path, params) when params == %{}, do: path
  defp build_url_with_params(path, params) do
    query_string = URI.encode_query(params)
    "#{path}?#{query_string}"
  end

  # Helper function to expand backward multiple times
  defp expand_backward_multiple(frame_sequence, count, added_so_far) when count > 0 do
    case Search.expand_frame_sequence_backward(frame_sequence) do
      {:ok, expanded_sequence} ->
        expand_backward_multiple(expanded_sequence, count - 1, added_so_far + 1)
      
      {:error, _reason} ->
        {frame_sequence, added_so_far}
    end
  end
  
  defp expand_backward_multiple(frame_sequence, 0, added_so_far) do
    {frame_sequence, added_so_far}
  end

  # Helper function to expand forward multiple times  
  defp expand_forward_multiple(frame_sequence, count, added_so_far) when count > 0 do
    case Search.expand_frame_sequence_forward(frame_sequence) do
      {:ok, expanded_sequence} ->
        expand_forward_multiple(expanded_sequence, count - 1, added_so_far + 1)
      
      {:error, _reason} ->
        {frame_sequence, added_so_far}
    end
  end
  
  defp expand_forward_multiple(frame_sequence, 0, added_so_far) do
    {frame_sequence, added_so_far}
  end

  @impl true
  def handle_info({:perform_search, term}, socket) when is_binary(term) do
    case Search.search_frames(term, socket.assigns.search_mode, socket.assigns.selected_video_ids) do
      {:ok, results} ->
        # Clear expanded state for new searches - all videos start collapsed
        socket =
          socket
          |> assign(:search_results, results)
          |> assign(:loading, false)
          |> assign(:expanded_videos, MapSet.new())

        {:noreply, socket}
      
      {:error, reason} ->
        socket =
          socket
          |> assign(:search_results, [])
          |> assign(:loading, false)
          |> put_flash(:error, "Search failed: #{reason}")

        {:noreply, socket}
    end
  end
  
  def handle_info({:perform_search, nil}, socket) do
    socket =
      socket
      |> assign(:search_results, [])
      |> assign(:loading, false)

    {:noreply, socket}
  end
  
  def handle_info({:perform_search, _invalid_term}, socket) do
    socket =
      socket
      |> assign(:search_results, [])
      |> assign(:loading, false)
      |> put_flash(:error, "Invalid search term")

    {:noreply, socket}
  end

  def handle_info({ref, result}, socket) do
    # Handle GIF generation task completion
    if socket.assigns[:gif_generation_task] && socket.assigns.gif_generation_task.ref == ref do
      Process.demonitor(ref, [:flush])
      
      case result do
        {:ok, gif_data} ->
          # Convert binary data to base64 for embedding
          gif_base64 = Base.encode64(gif_data)
          
          socket =
            socket
            |> assign(:gif_generation_status, :completed)
            |> assign(:generated_gif_data, gif_base64)
            |> assign(:gif_generation_task, nil)
            |> put_flash(:info, "GIF generated successfully!")
          
          {:noreply, socket}
        
        {:error, reason} ->
          socket =
            socket
            |> assign(:gif_generation_status, nil)
            |> assign(:gif_generation_task, nil)
            |> put_flash(:error, "GIF generation failed: #{reason}")
          
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    # Handle GIF generation task crash
    if socket.assigns[:gif_generation_task] && socket.assigns.gif_generation_task.ref == ref do
      socket =
        socket
        |> assign(:gif_generation_status, nil)
        |> assign(:gif_generation_task, nil)
        |> put_flash(:error, "GIF generation task crashed: #{inspect(reason)}")
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Welcome Modal for New Users -->
    <%= if @show_welcome_modal do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
        <div class="bg-white rounded-lg shadow-xl max-w-lg mx-4 p-6">
          <div class="text-center">
            <h2 class="text-2xl font-bold text-gray-900 mb-4">Welcome to Nathan For Us!</h2>
            <div class="text-left space-y-3 text-sm text-gray-700 mb-6">
              <p><strong>🎬 Search for any Nathan quote and find the exact frame!</strong></p>
              <p>• Type in quotes like <code class="bg-gray-100 px-1 rounded">"I graduated from business school"</code></p>
              <p>• Click frames to create animated GIFs</p>
              <p>• Use the video filter to search specific interviews</p>
              <p>• Expand frame sequences to get more context</p>
              <p class="text-blue-600 font-medium">Start by searching for something Nathan said in any of his interviews!</p>
            </div>
            <button 
              id="welcome-close-button"
              phx-click="close_welcome_modal"
              phx-hook="VideoSearchVisited"
              class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition-colors"
            >
              Got it, let's search!
            </button>
          </div>
        </div>
      </div>
    <% end %>

    <div id="video-search" phx-hook="VideoSearchWelcome" class="min-h-screen bg-zinc-50 text-zinc-900 p-4 md:p-6 font-mono">
      <div class="max-w-5xl mx-auto">
        <SearchHeader.search_header search_term={@search_term} results_count={length(@search_results)} />
        
        <div class="space-y-4">
          <SearchInterface.search_interface 
            search_term={@search_term}
            search_form={@search_form}
            loading={@loading}
            videos={@videos}
            search_mode={@search_mode}
            selected_video_ids={@selected_video_ids}
            autocomplete_suggestions={@autocomplete_suggestions}
            show_autocomplete={@show_autocomplete}
          />
          
          <SearchResults.search_results 
            :if={!@loading}
            search_results={@search_results}
            search_term={@search_term}
          />
          
          <SearchResults.loading_state :if={@loading} search_term={@search_term} />
        </div>
        
        <VideoFilter.video_filter_modal 
          :if={@show_video_modal}
          videos={@videos}
          selected_video_ids={@selected_video_ids}
        />
        
        <FrameSequence.frame_sequence_modal 
          :if={@show_sequence_modal}
          frame_sequence={@frame_sequence}
          selected_frame_indices={@selected_frame_indices}
          frame_sequence_version={@frame_sequence_version}
          gif_generation_status={@gif_generation_status}
          generated_gif_data={@generated_gif_data}
        />
      </div>
    </div>

    """
  end

end