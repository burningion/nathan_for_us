defmodule NathanForUsWeb.VideoTimelineLive do
  @moduledoc """
  Timeline-based video browser LiveView.

  Provides an intuitive timeline interface where users can drag to navigate
  through the entire video, see frame previews, and create GIFs from any section.
  """

  use NathanForUsWeb, :live_view

  alias NathanForUs.{Repo, AdminService}

  on_mount {NathanForUsWeb.UserAuth, :mount_current_user}
  alias NathanForUs.Video.VideoFrame
  alias NathanForUs.Gif
  alias NathanForUsWeb.Components.VideoTimeline.{
    TimelinePlayer,
    FrameDisplay,
    TimelineControls,
    CaptionSearch,
    GifPreview
  }

  require Logger

  @default_frames_per_page 50

  def handle_params(params, _url, socket) do
    search_term = Map.get(params, "search", "")
    context_frame = Map.get(params, "context_frame", "")
    is_random = Map.get(params, "random", "false") == "true"
    start_frame = Map.get(params, "start_frame", "")
    selected_indices = Map.get(params, "selected_indices", "")


    socket =
      cond do
        search_term != "" ->
          # Decode the URL-encoded search term
          decoded_search_term = URI.decode(search_term)

          # Set the search term and trigger the search automatically
          socket
          |> assign(:caption_search_term, decoded_search_term)
          |> then(fn socket ->
            # Trigger search if the term is long enough
            if String.length(decoded_search_term) >= 3 do
              if context_frame != "" do
                # If we have a context frame, trigger context view after search
                try do
                  context_frame_number = String.to_integer(context_frame)
                  send(self(), {:auto_search_from_params, decoded_search_term, context_frame_number})
                rescue
                  ArgumentError ->
                    send(self(), {:auto_search_from_params, decoded_search_term})
                end
              else
                send(self(), {:auto_search_from_params, decoded_search_term})
              end
            end
            socket
          end)
        
        is_random and start_frame != "" and selected_indices != "" ->
          # Handle random GIF generation
          try do
            start_frame_num = String.to_integer(start_frame)
            # Decode URL-encoded commas and parse indices
            decoded_indices = URI.decode(selected_indices)
            indices_list = decoded_indices
            |> String.split(",")
            |> Enum.map(&String.to_integer/1)
            
            # Load frames starting from the specified frame and mark as random selection
            send(self(), {:load_random_sequence, start_frame_num, indices_list})
            socket
            |> assign(:is_random_selection, true)
            |> assign(:random_start_frame, start_frame_num)
          rescue
            ArgumentError ->
              socket |> put_flash(:error, "Invalid random parameters")
          end
        
        true ->
          socket
      end

    {:noreply, socket}
  end

  def mount(%{"video_id" => video_id}, _session, socket) do
    try do
      video_id = String.to_integer(video_id)

      case NathanForUs.Video.get_video(video_id) do
        {:error, :not_found} ->
          socket =
            socket
            |> put_flash(:error, "Video not found")
            |> redirect(to: ~p"/video-timeline")

          {:ok, socket}

        {:ok, video} ->
          # Get video metadata
          {:ok, frame_count} = NathanForUs.Video.get_video_frame_count(video_id)
          video_duration_ms = NathanForUs.Video.get_video_duration_ms(video_id)

          socket =
            socket
            |> assign(:video, video)
            |> assign(:frame_count, frame_count)
            |> assign(:video_duration_ms, video_duration_ms || 0)
            |> assign(:timeline_position, 0.0)  # 0.0 to 1.0
            |> assign(:current_frames, [])
            |> assign(:loading_frames, false)
            |> assign(:frames_per_view, @default_frames_per_page)
            |> assign(:selected_frame_indices, [])
            |> assign(:timeline_zoom, 1.0)
            |> assign(:show_frame_modal, false)
            |> assign(:modal_frame, nil)
            |> assign(:modal_frame_captions, [])
            |> assign(:timeline_playing, false)
            |> assign(:playback_speed, 1.0)
            |> assign(:page_title, "Timeline: #{video.title}")
            |> assign(:show_tutorial_modal, false)
            |> assign(:caption_search_term, "")
            |> assign(:caption_search_form, to_form(%{}))
            |> assign(:caption_autocomplete_suggestions, [])
            |> assign(:show_caption_autocomplete, false)
            |> assign(:caption_loading, false)
            |> assign(:caption_filtered_frames, [])
            |> assign(:is_caption_filtered, false)
            |> assign(:context_frames, [])
            |> assign(:is_context_view, false)
            |> assign(:context_target_frame, nil)
            |> assign(:expand_count, 3)
            |> assign(:gif_generation_status, nil)
            |> assign(:generated_gif_data, nil)
            |> assign(:is_random_selection, false)
            |> assign(:random_start_frame, nil)
            |> assign(:is_admin, is_admin?(socket))
            |> assign(:gif_cache_status, nil)
            |> assign(:gif_from_cache, false)
            |> assign(:selected_frame_captions, [])

          # Load initial frames
          send(self(), {:load_frames_at_position, 0.0})

          {:ok, socket}
      end
    rescue
      ArgumentError ->
        socket =
          socket
          |> put_flash(:error, "Invalid video ID")
          |> redirect(to: ~p"/video-timeline")

        {:ok, socket}
    end
  end

  def handle_event("timeline_scrub", %{"position" => position_str}, socket) do
    try do
      position = String.to_float(position_str)
      position = max(0.0, min(1.0, position))  # Clamp between 0 and 1

      socket = assign(socket, :timeline_position, position)

      # Debounce frame loading to avoid too many requests
      Process.send_after(self(), {:load_frames_at_position, position}, 150)

      {:noreply, socket}
    rescue
      ArgumentError ->
        Logger.warning("Invalid timeline position: #{position_str}")
        {:noreply, socket}
    end
  end

  def handle_event("timeline_click", %{"position" => position_str}, socket) do
    try do
      position = String.to_float(position_str)
      position = max(0.0, min(1.0, position))

      socket =
        socket
        |> assign(:timeline_position, position)
        |> assign(:timeline_playing, false)

      send(self(), {:load_frames_at_position, position})

      {:noreply, socket}
    rescue
      ArgumentError ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_playback", _params, socket) do
    new_playing_state = !socket.assigns.timeline_playing

    socket = assign(socket, :timeline_playing, new_playing_state)

    if new_playing_state do
      send(self(), :advance_timeline)
    end

    {:noreply, socket}
  end

  def handle_event("set_playback_speed", %{"speed" => speed_str}, socket) do
    try do
      speed = String.to_float(speed_str)
      speed = max(0.1, min(4.0, speed))  # Clamp between 0.1x and 4x

      socket = assign(socket, :playback_speed, speed)
      {:noreply, socket}
    rescue
      ArgumentError ->
        {:noreply, socket}
    end
  end

  def handle_event("zoom_timeline", %{"zoom" => zoom_str}, socket) do
    try do
      zoom = String.to_float(zoom_str)
      zoom = max(0.1, min(10.0, zoom))  # Clamp between 0.1x and 10x

      socket = assign(socket, :timeline_zoom, zoom)
      {:noreply, socket}
    rescue
      ArgumentError ->
        {:noreply, socket}
    end
  end

  def handle_event("select_frame", %{"frame_index" => frame_index_str} = params, socket) do
    try do
      frame_index = String.to_integer(frame_index_str)
      shift_key = Map.get(params, "shift_key", "false") == "true"

      # If we're in caption filtered state AND not already in context view, clicking a frame should show context
      if socket.assigns.is_caption_filtered and not socket.assigns.is_context_view do
        # Get the clicked frame
        clicked_frame = Enum.at(socket.assigns.current_frames, frame_index)

        if clicked_frame do
          # Load context frames around this frame
          video_id = socket.assigns.video.id
          context_frames = NathanForUs.Video.get_frames_with_context(video_id, clicked_frame.frame_number, 5, 5)

          socket =
            socket
            |> assign(:context_frames, context_frames)
            |> assign(:is_context_view, true)
            |> assign(:context_target_frame, clicked_frame)
            |> assign(:current_frames, context_frames)
            |> assign(:selected_frame_indices, [])  # Clear selection

          {:noreply, socket}
        else
          {:noreply, socket}
        end
      else
        # Normal frame selection behavior
        current_selected = socket.assigns.selected_frame_indices

        new_selected =
          cond do
            shift_key ->
              # For shift-click, we'll handle it in select_frame_range
              current_selected
            frame_index in current_selected ->
              List.delete(current_selected, frame_index)
            true ->
              [frame_index | current_selected] |> Enum.sort()
          end

        socket = 
          socket
          |> assign(:selected_frame_indices, new_selected)
          |> load_selected_frame_captions()
        {:noreply, socket}
      end
    rescue
      ArgumentError ->
        {:noreply, socket}
    end
  end

  def handle_event("select_frame_range", %{"start_index" => _start_str, "end_index" => _end_str, "indices" => indices_list}, socket) do
    try do
      range_indices = Enum.map(indices_list, &String.to_integer/1)

      current_selected = socket.assigns.selected_frame_indices

      # Add range to current selection (union)
      new_selected =
        (current_selected ++ range_indices)
        |> Enum.uniq()
        |> Enum.sort()

      socket = 
        socket
        |> assign(:selected_frame_indices, new_selected)
        |> load_selected_frame_captions()
      {:noreply, socket}
    rescue
      ArgumentError ->
        {:noreply, socket}
    end
  end

  def handle_event("preview_frame_selection", %{"indices" => _indices_list}, socket) do
    # This is just for preview during drag selection - don't actually update selection yet
    {:noreply, socket}
  end

  def handle_event("show_frame_modal", %{"frame_id" => frame_id_str}, socket) do
    try do
      frame_id = String.to_integer(frame_id_str)

      case Repo.get(VideoFrame, frame_id) do
        nil ->
          {:noreply, put_flash(socket, :error, "Frame not found")}

        frame ->
          # Get captions for this frame
          captions = NathanForUs.Video.get_frame_captions(frame_id)

          socket =
            socket
            |> assign(:show_frame_modal, true)
            |> assign(:modal_frame, frame)
            |> assign(:modal_frame_captions, captions)

          {:noreply, socket}
      end
    rescue
      ArgumentError ->
        {:noreply, socket}
    end
  end

  def handle_event("close_frame_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_frame_modal, false)
      |> assign(:modal_frame, nil)
      |> assign(:modal_frame_captions, [])

    {:noreply, socket}
  end

  def handle_event("close_tutorial_modal", _params, socket) do
    socket = assign(socket, :show_tutorial_modal, false)
    {:noreply, socket}
  end

  def handle_event("show_tutorial_modal", _params, socket) do
    socket = assign(socket, :show_tutorial_modal, true)
    {:noreply, socket}
  end


  def handle_event("caption_autocomplete", %{"caption_search" => %{"term" => term}}, socket) do
    term = String.trim(term)

    socket = assign(socket, :caption_search_term, term)

    if String.length(term) >= 3 do
      video_id = socket.assigns.video.id
      suggestions = NathanForUs.Video.get_autocomplete_suggestions(term, video_id, 5)

      socket =
        socket
        |> assign(:caption_autocomplete_suggestions, suggestions)
        |> assign(:show_caption_autocomplete, length(suggestions) > 0)
    else
      socket =
        socket
        |> assign(:caption_autocomplete_suggestions, [])
        |> assign(:show_caption_autocomplete, false)
    end

    {:noreply, socket}
  end

  def handle_event("select_caption_suggestion", %{"suggestion" => suggestion}, socket) do
    socket =
      socket
      |> assign(:caption_search_term, suggestion)
      |> assign(:show_caption_autocomplete, false)

    {:noreply, socket}
  end

  def handle_event("hide_caption_autocomplete", _params, socket) do
    socket = assign(socket, :show_caption_autocomplete, false)
    {:noreply, socket}
  end

  def handle_event("caption_search", %{"caption_search" => %{"term" => term}}, socket) do
    term = String.trim(term)

    if String.length(term) >= 3 do
      socket = assign(socket, :caption_loading, true)

      # Search for frames with matching captions in this video
      video_id = socket.assigns.video.id
      filtered_frames = NathanForUs.Video.get_video_frames_with_caption_text(video_id, term)

      socket =
        socket
        |> assign(:caption_filtered_frames, filtered_frames)
        |> assign(:is_caption_filtered, true)
        |> assign(:current_frames, filtered_frames)
        |> assign(:caption_loading, false)
        |> assign(:show_caption_autocomplete, false)
        |> assign(:selected_frame_indices, [])  # Clear selection
        |> assign(:is_context_view, false)  # Reset context view
        |> assign(:context_frames, [])
        |> assign(:context_target_frame, nil)

      {:noreply, socket}
    else
      socket = put_flash(socket, :error, "Search term must be at least 3 characters")
      {:noreply, socket}
    end
  end

  def handle_event("clear_caption_filter", _params, socket) do
    # Clear the caption filter and reload frames at current timeline position
    socket =
      socket
      |> assign(:caption_filtered_frames, [])
      |> assign(:is_caption_filtered, false)
      |> assign(:caption_search_term, "")
      |> assign(:selected_frame_indices, [])
      |> assign(:context_frames, [])
      |> assign(:is_context_view, false)
      |> assign(:context_target_frame, nil)
      |> assign(:expand_count, 3)  # Reset to default

    # Reload frames at current position
    send(self(), {:load_frames_at_position, socket.assigns.timeline_position})

    {:noreply, socket}
  end

  def handle_event("reload_all_frames", _params, socket) do
    # Clear any search filters and reload all frames at current timeline position
    socket =
      socket
      |> assign(:caption_filtered_frames, [])
      |> assign(:is_caption_filtered, false)
      |> assign(:caption_search_term, "")
      |> assign(:selected_frame_indices, [])
      |> assign(:context_frames, [])
      |> assign(:is_context_view, false)
      |> assign(:context_target_frame, nil)
      |> assign(:expand_count, 3)

    # Reload frames at current position
    send(self(), {:load_frames_at_position, socket.assigns.timeline_position})

    {:noreply, socket}
  end

  def handle_event("back_to_search_results", _params, socket) do
    # Go back from context view to the filtered search results
    socket =
      socket
      |> assign(:current_frames, socket.assigns.caption_filtered_frames)
      |> assign(:is_context_view, false)
      |> assign(:context_frames, [])
      |> assign(:context_target_frame, nil)
      |> assign(:selected_frame_indices, [])

    {:noreply, socket}
  end

  def handle_event("update_expand_count", %{"expand_count" => count_str}, socket) do
    try do
      count = String.to_integer(count_str)
      count = max(1, min(20, count))  # Clamp between 1 and 20

      socket = assign(socket, :expand_count, count)
      {:noreply, socket}
    rescue
      ArgumentError ->
        {:noreply, socket}
    end
  end

  def handle_event("expand_random_left", _params, socket) do
    if socket.assigns.is_random_selection do
      video_id = socket.assigns.video.id
      current_frames = socket.assigns.current_frames
      expand_count = socket.assigns.expand_count
      
      # Find the earliest frame number in current selection
      earliest_frame_number = current_frames |> Enum.map(& &1.frame_number) |> Enum.min()
      
      # Calculate new start frame
      new_start_frame = max(1, earliest_frame_number - expand_count)
      
      if new_start_frame < earliest_frame_number do
        # Get additional frames
        additional_frames = NathanForUs.Video.get_video_frames_in_range(
          video_id, 
          new_start_frame, 
          earliest_frame_number - 1
        )
        
        # Combine with existing frames
        new_frames = additional_frames ++ current_frames
        
        # Update selection indices to include the new frames
        additional_count = length(additional_frames)
        updated_indices = socket.assigns.selected_frame_indices
        |> Enum.map(&(&1 + additional_count))  # Shift existing indices
        |> then(&(Enum.to_list(0..(additional_count - 1)) ++ &1))  # Add new indices
        
        socket =
          socket
          |> assign(:current_frames, new_frames)
          |> assign(:selected_frame_indices, updated_indices)
          |> assign(:random_start_frame, new_start_frame)

        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("expand_random_right", _params, socket) do
    if socket.assigns.is_random_selection do
      video_id = socket.assigns.video.id
      current_frames = socket.assigns.current_frames
      expand_count = socket.assigns.expand_count
      
      # Find the latest frame number in current selection
      latest_frame_number = current_frames |> Enum.map(& &1.frame_number) |> Enum.max()
      
      # Calculate new end frame
      new_end_frame = latest_frame_number + expand_count
      
      # Get additional frames
      additional_frames = NathanForUs.Video.get_video_frames_in_range(
        video_id, 
        latest_frame_number + 1, 
        new_end_frame
      )
      
      if not Enum.empty?(additional_frames) do
        # Combine with existing frames
        new_frames = current_frames ++ additional_frames
        
        # Update selection indices to include the new frames
        current_count = length(current_frames)
        additional_count = length(additional_frames)
        new_indices = Enum.to_list(current_count..(current_count + additional_count - 1))
        updated_indices = socket.assigns.selected_frame_indices ++ new_indices
        
        socket =
          socket
          |> assign(:current_frames, new_frames)
          |> assign(:selected_frame_indices, updated_indices)

        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("clear_random_selection", _params, socket) do
    socket =
      socket
      |> assign(:is_random_selection, false)
      |> assign(:random_start_frame, nil)
      |> assign(:selected_frame_indices, [])
    
    # Reload frames at current position
    send(self(), {:load_frames_at_position, socket.assigns.timeline_position})
    
    {:noreply, socket}
  end

  def handle_event("expand_context_left", _params, socket) do
    if socket.assigns.is_context_view and socket.assigns.context_target_frame do
      video_id = socket.assigns.video.id
      current_frames = socket.assigns.current_frames
      target_frame = socket.assigns.context_target_frame
      expand_count = socket.assigns.expand_count

      expanded_frames = NathanForUs.Video.expand_context_left(
        video_id,
        current_frames,
        target_frame.frame_number,
        expand_count
      )

      socket =
        socket
        |> assign(:current_frames, expanded_frames)
        |> assign(:context_frames, expanded_frames)
        |> assign(:selected_frame_indices, [])  # Clear selection

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("expand_context_right", _params, socket) do
    if socket.assigns.is_context_view and socket.assigns.context_target_frame do
      video_id = socket.assigns.video.id
      current_frames = socket.assigns.current_frames
      target_frame = socket.assigns.context_target_frame
      expand_count = socket.assigns.expand_count

      expanded_frames = NathanForUs.Video.expand_context_right(
        video_id,
        current_frames,
        target_frame.frame_number,
        expand_count
      )

      socket =
        socket
        |> assign(:current_frames, expanded_frames)
        |> assign(:context_frames, expanded_frames)
        |> assign(:selected_frame_indices, [])  # Clear selection

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("generate_timeline_gif_server", _params, socket) do
    # Generate GIF on server side using selected frames
    selected_frames = get_selected_frames(socket)
    video_id = socket.assigns.video.id
    
    case selected_frames do
      [] ->
        {:noreply, socket}
      frames ->
        # Check if GIF already exists
        case Gif.find_or_prepare(video_id, frames) do
          {:ok, existing_gif} ->
            # GIF already exists, use cached version
            gif_base64 = Gif.to_base64(existing_gif)
            
            socket =
              socket
              |> assign(:gif_generation_status, :completed)
              |> assign(:generated_gif_data, gif_base64)
              |> assign(:gif_generation_task, nil)
              |> assign(:gif_from_cache, true)
              |> assign(:gif_cache_status, "Loaded from database cache (ID: #{existing_gif.id})")

            {:noreply, socket}

          {:generate, hash, frame_ids} ->
            # Need to generate new GIF
            task = Task.async(fn ->
              # Create a mock frame sequence for the existing GIF generation function
              mock_sequence = %{sequence_frames: frames}
              selected_indices = 0..(length(frames) - 1) |> Enum.to_list()
              
              case NathanForUs.AdminService.generate_gif_from_frames(mock_sequence, selected_indices) do
                {:ok, gif_binary} ->
                  # Save the generated GIF to database
                  case Gif.save_generated_gif(hash, video_id, frame_ids, gif_binary) do
                    {:ok, saved_gif} ->
                      # Also create a browseable GIF entry automatically
                      create_browseable_gif_from_generation(frames, socket.assigns.video, socket.assigns[:current_user], saved_gif)
                      {:ok, gif_binary, saved_gif}
                    {:error, _reason} ->
                      # Still return the GIF even if saving failed
                      {:ok, gif_binary, nil}
                  end
                {:error, reason} ->
                  {:error, reason}
              end
            end)

            socket =
              socket
              |> assign(:gif_generation_status, :generating)
              |> assign(:gif_generation_task, task)
              |> assign(:generated_gif_data, nil)

            {:noreply, socket}
        end
    end
  end

  def handle_event("reset_gif_generation", _params, socket) do
    socket =
      socket
      |> assign(:gif_generation_status, nil)
      |> assign(:generated_gif_data, nil)

    {:noreply, socket}
  end

  def handle_event("random_gif", _params, socket) do
    case NathanForUs.Video.get_random_video_sequence(15) do
      {:ok, video_id, start_frame} ->
        # Generate a range of 15 frame indices starting from the random frame
        frame_indices = Enum.to_list(0..14)
        indices_param = Enum.join(frame_indices, ",")
        
        # Navigate to the video timeline with pre-selected frames
        path = ~p"/video-timeline/#{video_id}?random=true&start_frame=#{start_frame}&selected_indices=#{indices_param}"
        socket = redirect(socket, to: path)
        {:noreply, socket}
      
      {:error, _reason} ->
        socket = put_flash(socket, :error, "No suitable videos found for random GIF generation")
        {:noreply, socket}
    end
  end

  def handle_event("post_to_timeline", _params, socket) do
    # Only allow authenticated users
    if socket.assigns[:current_user] do
      # Only allow posting if GIF is generated and cached
      if socket.assigns.gif_generation_status == :completed and socket.assigns.generated_gif_data do
        selected_frames = get_selected_frames(socket)
        video = socket.assigns.video
        user = socket.assigns.current_user
        
        # Create viral GIF entry
        case create_viral_gif_from_selection(selected_frames, video, user) do
          {:ok, _viral_gif} ->
            socket =
              socket
              |> put_flash(:info, "GIF posted to timeline! Check it out in the public timeline.")
              |> assign(:gif_generation_status, nil)
              |> assign(:generated_gif_data, nil)
            
            {:noreply, socket}
          
          {:error, _reason} ->
            socket = put_flash(socket, :error, "Failed to post GIF to timeline")
            {:noreply, socket}
        end
      else
        socket = put_flash(socket, :error, "Please generate a GIF first before posting")
        {:noreply, socket}
      end
    else
      socket = put_flash(socket, :error, "Please log in to post to timeline")
      {:noreply, socket}
    end
  end

  def handle_info({:load_frames_at_position, position}, socket) do
    # Only load if this is the current position (debouncing)
    if position == socket.assigns.timeline_position do
      socket = assign(socket, :loading_frames, true)

      # If caption filtered, don't load new frames - keep the filtered ones
      if socket.assigns.is_caption_filtered do
        socket =
          socket
          |> assign(:current_frames, socket.assigns.caption_filtered_frames)
          |> assign(:loading_frames, false)
          |> assign(:selected_frame_indices, [])  # Clear selection when moving

        {:noreply, socket}
      else
        # Normal timeline navigation - load frames in range
        frame_count = socket.assigns.frame_count
        frames_per_view = socket.assigns.frames_per_view

        # Convert position (0.0-1.0) to frame range
        start_frame = round(position * (frame_count - frames_per_view))
        start_frame = max(0, start_frame)

        end_frame = min(start_frame + frames_per_view - 1, frame_count - 1)

        # Load frames in this range
        frames = NathanForUs.Video.get_video_frames_in_range(socket.assigns.video.id, start_frame, end_frame)

        socket =
          socket
          |> assign(:current_frames, frames)
          |> assign(:loading_frames, false)
          |> assign(:selected_frame_indices, [])  # Clear selection when moving

        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(:advance_timeline, socket) do
    if socket.assigns.timeline_playing do
      # Calculate how much to advance based on playback speed
      # Advance by 1 frame worth of time
      frame_count = socket.assigns.frame_count
      if frame_count > 0 do
        frame_duration = 1.0 / frame_count
        speed_multiplier = socket.assigns.playback_speed
        advancement = frame_duration * speed_multiplier

        new_position = socket.assigns.timeline_position + advancement

        if new_position >= 1.0 do
          # Reached end, stop playback
          socket = assign(socket, :timeline_playing, false)
          {:noreply, socket}
        else
          socket = assign(socket, :timeline_position, new_position)
          send(self(), {:load_frames_at_position, new_position})

          # Schedule next advancement
          Process.send_after(self(), :advance_timeline, 100)

          {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:auto_search_from_params, search_term}, socket) do
    # Automatically perform caption search with the URL parameter
    # Only proceed if video is loaded
    if Map.has_key?(socket.assigns, :video) && socket.assigns.video do
      video_id = socket.assigns.video.id
      filtered_frames = NathanForUs.Video.get_video_frames_with_caption_text(video_id, search_term)

      socket =
        socket
        |> assign(:caption_filtered_frames, filtered_frames)
        |> assign(:is_caption_filtered, true)
        |> assign(:current_frames, filtered_frames)
        |> assign(:caption_loading, false)
        |> assign(:show_caption_autocomplete, false)
        |> assign(:selected_frame_indices, [])
        |> assign(:is_context_view, false)  # Reset context view
        |> assign(:context_frames, [])
        |> assign(:context_target_frame, nil)

      {:noreply, socket}
    else
      # Video not loaded yet, reschedule the search
      Process.send_after(self(), {:auto_search_from_params, search_term}, 100)
      {:noreply, socket}
    end
  end

  def handle_info({:auto_search_from_params, search_term, context_frame_number}, socket) do
    # Automatically perform caption search and then load context for the specified frame
    # Only proceed if video is loaded
    if Map.has_key?(socket.assigns, :video) && socket.assigns.video do
      video_id = socket.assigns.video.id
      filtered_frames = NathanForUs.Video.get_video_frames_with_caption_text(video_id, search_term)

      # Find the target frame in the filtered results
      target_frame = Enum.find(filtered_frames, fn frame -> frame.frame_number == context_frame_number end)

      if target_frame do
        # Load context frames around this frame
        context_frames = NathanForUs.Video.get_frames_with_context(video_id, target_frame.frame_number, 5, 5)

        socket =
          socket
          |> assign(:caption_filtered_frames, filtered_frames)
          |> assign(:is_caption_filtered, true)
          |> assign(:context_frames, context_frames)
          |> assign(:is_context_view, true)
          |> assign(:context_target_frame, target_frame)
          |> assign(:current_frames, context_frames)
          |> assign(:caption_loading, false)
          |> assign(:show_caption_autocomplete, false)
          |> assign(:selected_frame_indices, [])
          |> load_selected_frame_captions()

        {:noreply, socket}
      else
        # Target frame not found in search results, fall back to regular search
        send(self(), {:auto_search_from_params, search_term})
        {:noreply, socket}
      end
    else
      # Video not loaded yet, reschedule the search
      Process.send_after(self(), {:auto_search_from_params, search_term, context_frame_number}, 100)
      {:noreply, socket}
    end
  end

  def handle_info({ref, result}, socket) do
    # Handle server-side GIF generation task completion
    if socket.assigns[:gif_generation_task] && socket.assigns.gif_generation_task.ref == ref do
      Process.demonitor(ref, [:flush])

      case result do
        {:ok, gif_binary, saved_gif} ->
          # Convert binary data to base64 for embedding
          gif_base64 = Base.encode64(gif_binary)

          {cache_status, from_cache} = case saved_gif do
            nil -> {"Generated fresh (save to DB failed)", false}
            gif -> {"Generated fresh, saved to DB (ID: #{gif.id})", false}
          end

          socket =
            socket
            |> assign(:gif_generation_status, :completed)
            |> assign(:generated_gif_data, gif_base64)
            |> assign(:gif_generation_task, nil)
            |> assign(:gif_from_cache, from_cache)
            |> assign(:gif_cache_status, cache_status)

          {:noreply, socket}

        {:error, _reason} ->
          socket =
            socket
            |> assign(:gif_generation_status, nil)
            |> assign(:gif_generation_task, nil)

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, socket) do
    # Handle server-side GIF generation task crash
    if socket.assigns[:gif_generation_task] && socket.assigns.gif_generation_task.ref == ref do
      socket =
        socket
        |> assign(:gif_generation_status, nil)
        |> assign(:gif_generation_task, nil)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:load_random_sequence, start_frame_num, indices_list}, socket) do
    # Load frames starting from the specified frame number
    video_id = socket.assigns.video.id
    end_frame_num = start_frame_num + 14  # 15 frames total (0-14 indices)
    
    frames = NathanForUs.Video.get_video_frames_in_range(video_id, start_frame_num, end_frame_num)
    
    # Update timeline position to the start of the sequence
    frame_count = socket.assigns.frame_count
    timeline_position = if frame_count > 0, do: start_frame_num / frame_count, else: 0.0
    
    socket =
      socket
      |> assign(:current_frames, frames)
      |> assign(:selected_frame_indices, indices_list)
      |> assign(:timeline_position, timeline_position)
      |> assign(:is_caption_filtered, false)
      |> assign(:is_context_view, false)
      |> load_selected_frame_captions()

    # Automatically check if GIF exists for random sequences
    if length(frames) >= 2 do
      send(self(), :auto_check_existing_gif)
    end

    {:noreply, socket}
  end

  def handle_info(:auto_check_existing_gif, socket) do
    # Automatically check if GIF exists for the currently selected frames
    selected_frames = get_selected_frames(socket)
    video_id = socket.assigns.video.id
    
    case selected_frames do
      frames when length(frames) >= 2 ->
        # Check if GIF already exists
        case Gif.find_or_prepare(video_id, frames) do
          {:ok, existing_gif} ->
            # GIF already exists, load it automatically
            gif_base64 = Gif.to_base64(existing_gif)
            
            socket =
              socket
              |> assign(:gif_generation_status, :completed)
              |> assign(:generated_gif_data, gif_base64)
              |> assign(:gif_generation_task, nil)
              |> assign(:gif_from_cache, true)
              |> assign(:gif_cache_status, "Automatically loaded from database cache (ID: #{existing_gif.id})")

            {:noreply, socket}

          {:generate, _hash, _frame_ids} ->
            # GIF doesn't exist yet, just show preview
            {:noreply, socket}
        end
      
      _ ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white" phx-hook="TimelineTutorial" id="timeline-container">
      <!-- Header -->
      <div class="bg-gray-800 border-b border-gray-700 px-6 py-4">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold font-mono"><%= @video.title %></h1>
            <p class="text-gray-400 text-sm font-mono">
              Timeline Browser • <%= @frame_count %> frames • <%= format_duration(@video_duration_ms) %>
            </p>
          </div>

          <div class="flex items-center gap-4">
            <.link
              navigate={~p"/video-timeline"}
              class="text-blue-400 hover:text-blue-300 font-mono text-sm"
            >
              ← Back to Search
            </.link>

            <.link
              navigate={~p"/public-timeline"}
              class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded font-mono font-medium transition-colors text-sm"
            >
              TIMELINE
            </.link>

            <.link
              navigate={~p"/browse-gifs"}
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded font-mono font-medium transition-colors text-sm"
            >
              BROWSE GIFS
            </.link>

            <button
              phx-click="random_gif"
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded font-mono font-medium transition-colors text-sm"
              title="Generate random GIF from any video"
            >
              🎲 Random GIF
            </button>

            <button
              phx-click="reload_all_frames"
              class={[
                "text-white px-4 py-2 rounded font-mono transition-all",
                if(@is_caption_filtered or @is_context_view,
                  do: "bg-blue-600 hover:bg-blue-700 text-sm font-bold shadow-lg",
                  else: "bg-gray-600 hover:bg-gray-500 text-xs px-3 py-1"
                )
              ]}
              title={
                if(@is_caption_filtered or @is_context_view,
                  do: "Return to full timeline view",
                  else: "Reload all frames (clear search filter)"
                )
              }
            >
              <%= if @is_caption_filtered or @is_context_view do %>
                ← Back to Timeline
              <% else %>
                Reload All
              <% end %>
            </button>
          </div>
        </div>
      </div>

      <!-- Caption Search -->
      <div class="px-6">
        <CaptionSearch.caption_search
          search_term={@caption_search_term}
          loading={@caption_loading}
          video_id={@video.id}
          autocomplete_suggestions={@caption_autocomplete_suggestions}
          show_autocomplete={@show_caption_autocomplete}
          search_form={@caption_search_form}
          is_filtered={@is_caption_filtered}
          is_context_view={@is_context_view}
          context_target_frame={@context_target_frame}
          expand_count={@expand_count}
        />
      </div>

      <!-- Timeline Controls (hidden when searching or in context view) -->
      <%= unless @is_caption_filtered or @is_context_view do %>
        <TimelineControls.timeline_controls
          timeline_position={@timeline_position}
          timeline_playing={@timeline_playing}
          playback_speed={@playback_speed}
          timeline_zoom={@timeline_zoom}
          frame_count={@frame_count}
          video_duration_ms={@video_duration_ms}
        />

        <!-- Timeline Player -->
        <TimelinePlayer.timeline_player
          timeline_position={@timeline_position}
          timeline_zoom={@timeline_zoom}
          frame_count={@frame_count}
          video_duration_ms={@video_duration_ms}
          video={@video}
        />
      <% end %>

      <!-- GIF Preview (shows when frames are selected) -->
      <GifPreview.gif_preview
        current_frames={@current_frames}
        selected_frame_indices={@selected_frame_indices}
        gif_generation_status={@gif_generation_status}
        generated_gif_data={@generated_gif_data}
        is_admin={@is_admin}
        gif_cache_status={@gif_cache_status}
        gif_from_cache={@gif_from_cache}
        current_user={@current_user}
        video_id={@video.id}
        selected_frame_captions={@selected_frame_captions}
      />

      <!-- Random Selection Controls (show when in random selection mode) -->
      <%= if @is_random_selection do %>
        <div class="px-6 py-4 bg-gray-800 border-b border-gray-700">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-lg font-bold font-mono text-purple-400 mb-2">🎲 Random Selection Mode</h3>
              <p class="text-gray-400 text-sm font-mono">
                Selected <%= length(@selected_frame_indices) %> frames starting from frame #<%= @random_start_frame %>
              </p>
            </div>
            
            <div class="flex items-center gap-4">
              <div class="flex items-center gap-2">
                <label class="text-gray-300 text-sm font-mono">Expand by:</label>
                <select 
                  phx-change="update_expand_count"
                  name="expand_count"
                  class="bg-gray-700 border border-gray-600 text-white px-2 py-1 rounded text-sm font-mono"
                >
                  <%= for count <- [1, 2, 3, 5, 10] do %>
                    <option value={count} selected={@expand_count == count}><%= count %> frames</option>
                  <% end %>
                </select>
              </div>
              
              <button
                phx-click="expand_random_left"
                class="bg-gray-700 hover:bg-gray-600 text-white px-3 py-2 rounded font-mono text-sm transition-colors"
                title="Add frames to the left"
              >
                ← Add Left
              </button>
              
              <button
                phx-click="expand_random_right"
                class="bg-gray-700 hover:bg-gray-600 text-white px-3 py-2 rounded font-mono text-sm transition-colors"
                title="Add frames to the right"
              >
                Add Right →
              </button>
              
              <button
                phx-click="clear_random_selection"
                class="bg-gray-600 hover:bg-gray-500 text-white px-3 py-2 rounded font-mono text-sm transition-colors"
                title="Exit random selection mode"
              >
                Clear
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Frame Display -->
      <FrameDisplay.frame_display
        current_frames={@current_frames}
        loading_frames={@loading_frames}
        selected_frame_indices={@selected_frame_indices}
        timeline_position={@timeline_position}
        is_context_view={@is_context_view}
        is_caption_filtered={@is_caption_filtered}
        expand_count={@expand_count}
      />

      <!-- Tutorial Modal -->
      <%= if @show_tutorial_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-80 flex items-center justify-center z-50">
          <div class="bg-gray-800 rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto border border-gray-600">
            <div class="p-8">
              <div class="flex items-center justify-between mb-6">
                <h2 class="text-2xl font-bold font-mono text-blue-400">Welcome to Timeline Browser</h2>
                <button
                  phx-click="close_tutorial_modal"
                  class="text-gray-400 hover:text-white transition-colors"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
              </div>

              <div class="space-y-6 text-gray-200">
                <div class="flex items-start gap-4">
                  <div class="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center font-bold text-sm">1</div>
                  <div>
                    <h3 class="text-lg font-semibold mb-2 text-white">Navigate with the Timeline</h3>
                    <p class="leading-relaxed">Drag the scrubber along the timeline to jump to any point in the video. Click anywhere on the timeline track to jump directly to that position. Use the zoom controls to get more precise control over smaller sections.</p>
                  </div>
                </div>

                <div class="flex items-start gap-4">
                  <div class="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center font-bold text-sm">2</div>
                  <div>
                    <h3 class="text-lg font-semibold mb-2 text-white">Playback Controls</h3>
                    <p class="leading-relaxed">Use the play/pause button to automatically advance through the timeline. When playing, it cycles through frames at your selected speed (0.25x to 4x). The play button will automatically pause when it reaches the end of the video or when you interact with the timeline. The current frame position and timestamp are always displayed.</p>
                  </div>
                </div>


                <div class="flex items-start gap-4">
                  <div class="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center font-bold text-sm">4</div>
                  <div>
                    <h3 class="text-lg font-semibold mb-2 text-white">Search</h3>
                    <p class="leading-relaxed">Search for quotes at the top and find video from specific portions</p>
                  </div>
                </div>

                <div class="flex items-start gap-4">
                  <div class="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center font-bold text-sm">5</div>
                  <div>
                    <h3 class="text-lg font-semibold mb-2 text-white">Contextual View</h3>
                    <p class="leading-relaxed">Click a frame's image and get a contextual view to load frames before/after what you have and create a sequence</p>
                  </div>
                </div>
                <div class="flex items-start gap-4">
                  <div class="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center font-bold text-sm">6</div>
                  <div>
                    <h3 class="text-lg font-semibold mb-2 text-white">Click and Draft</h3>
                    <p class="leading-relaxed">Click and drag or click and then hold shift and click again for multi frame selection</p>
                  </div>
                </div>


                <div class="bg-gray-700 p-4 rounded-lg mt-6">
                  <h4 class="font-semibold text-white mb-2">💡 Pro Tips</h4>
                  <ul class="text-sm space-y-1 text-gray-300">
                    <li>• Click on any frame to open it in a larger modal view</li>
                    <li>• Use keyboard shortcuts: Space to play/pause, arrow keys to scrub</li>
                    <li>• The timeline shows your current position as a percentage and timestamp</li>
                    <li>• Zoom in on interesting sections for frame-perfect selection</li>
                  </ul>
                </div>
              </div>

              <div class="flex justify-end mt-8">
                <button
                  phx-click="close_tutorial_modal"
                  phx-hook="TimelineTutorialButton"
                  id="tutorial-got-it-btn"
                  class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded font-mono font-medium transition-colors"
                >
                  Got it!
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Frame Modal -->
      <%= if @show_frame_modal and @modal_frame do %>
        <div class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50">
          <div class="bg-gray-800 rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto">
            <div class="p-6">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-bold font-mono">Frame #<%= @modal_frame.frame_number %></h3>
                <button
                  phx-click="close_frame_modal"
                  class="text-gray-400 hover:text-white"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
              </div>

              <div class="text-center">
                <%= if @modal_frame.image_data do %>
                  <img
                    src={"data:image/jpeg;base64,#{encode_frame_image(@modal_frame.image_data)}"}
                    alt={"Frame ##{@modal_frame.frame_number}"}
                    class="max-w-full max-h-96 mx-auto rounded"
                  />
                <% else %>
                  <div class="bg-gray-700 h-64 flex items-center justify-center rounded">
                    <span class="text-gray-400">No image data</span>
                  </div>
                <% end %>

                <div class="mt-4 text-sm font-mono text-gray-300">
                  <p>Timestamp: <%= format_timestamp(@modal_frame.timestamp_ms) %></p>
                  <%= if @modal_frame.width != nil and @modal_frame.height != nil do %>
                    <p>Resolution: <%= @modal_frame.width %>x<%= @modal_frame.height %></p>
                  <% end %>
                </div>

                <!-- Frame Captions -->
                <%= if length(@modal_frame_captions) > 0 do %>
                  <div class="mt-6 bg-gray-700 rounded-lg p-4">
                    <h4 class="text-sm font-bold text-blue-400 mb-3 uppercase tracking-wide">Captions</h4>
                    <div class="space-y-2">
                      <%= for caption <- @modal_frame_captions do %>
                        <div class="bg-gray-600 rounded p-3 text-left">
                          <p class="text-gray-200 text-sm leading-relaxed"><%= caption %></p>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% else %>
                  <div class="mt-6 bg-gray-700 rounded-lg p-4">
                    <h4 class="text-sm font-bold text-blue-400 mb-3 uppercase tracking-wide">Captions</h4>
                    <p class="text-gray-400 text-sm italic">No captions found for this frame</p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  # Load captions for selected frames
  defp load_selected_frame_captions(socket) do
    selected_frames = get_selected_frames(socket)
    
    frame_captions = Enum.map(selected_frames, fn frame ->
      captions = NathanForUs.Video.get_frame_captions(frame.id)
      %{
        frame_id: frame.id,
        frame_number: frame.frame_number,
        timestamp_ms: frame.timestamp_ms,
        captions: captions
      }
    end)
    
    assign(socket, :selected_frame_captions, frame_captions)
  end

  # Check if current user is admin
  defp is_admin?(socket) do
    case Map.get(socket.assigns, :current_user) do
      nil -> false
      user -> AdminService.validate_admin_access(user) == :ok
    end
  end

  # Get selected frames based on current indices
  defp get_selected_frames(socket) do
    socket.assigns.selected_frame_indices
    |> Enum.map(&Enum.at(socket.assigns.current_frames, &1))
    |> Enum.reject(&is_nil/1)
  end

  # Create viral GIF from selected frames
  defp create_viral_gif_from_selection(frames, video, user) do
    if length(frames) >= 2 do
      first_frame = List.first(frames)
      last_frame = List.last(frames)
      
      # Find the GIF in the database by generating hash
      frame_ids = Enum.map(frames, & &1.id)
      hash = NathanForUs.Gif.generate_hash(video.id, frame_ids)
      gif = NathanForUs.Gif.find_by_hash(hash)
      
      # Determine category based on frame content or default
      category = determine_gif_category(frames)
      
      # Create frame data for storage
      frame_data = Jason.encode!(%{
        frame_ids: frame_ids,
        frame_numbers: Enum.map(frames, & &1.frame_number),
        timestamps: Enum.map(frames, & &1.timestamp_ms)
      })
      
      attrs = %{
        video_id: video.id,
        created_by_user_id: user.id,
        gif_id: gif && gif.id, # Link to actual GIF binary
        start_frame_index: first_frame.frame_number,
        end_frame_index: last_frame.frame_number,
        category: category,
        frame_data: frame_data,
        title: generate_gif_title(category, video.title)
      }
      
      NathanForUs.Viral.create_viral_gif(attrs)
    else
      {:error, :insufficient_frames}
    end
  end

  # Determine GIF category (basic implementation)
  defp determine_gif_category(frames) do
    # For now, randomly assign a category - could be enhanced with AI analysis
    categories = NathanForUs.Viral.nathan_categories()
    Enum.random(categories)
  end

  # Generate a title for the GIF
  defp generate_gif_title(category, video_title) do
    base_title = NathanForUs.Viral.ViralGif.generate_title(category)
    "#{base_title} (#{video_title})"
  end

  # Create browseable GIF from generation (automatically called on every GIF generation)
  defp create_browseable_gif_from_generation(frames, video, user, saved_gif) do
    if length(frames) >= 2 do
      first_frame = List.first(frames)
      last_frame = List.last(frames)
      category = determine_gif_category(frames)
      
      frame_data = Jason.encode!(%{
        frame_ids: Enum.map(frames, & &1.id),
        frame_numbers: Enum.map(frames, & &1.frame_number),
        timestamps: Enum.map(frames, & &1.timestamp_ms)
      })
      
      attrs = %{
        video_id: video.id,
        created_by_user_id: user && user.id, # Allow anonymous for now
        gif_id: saved_gif.id,
        start_frame_index: first_frame.frame_number,
        end_frame_index: last_frame.frame_number,
        category: category,
        frame_data: frame_data,
        title: NathanForUs.Viral.BrowseableGif.generate_title(category, video.title),
        is_public: true
      }
      
      # Don't fail the main flow if this fails
      case NathanForUs.Viral.create_browseable_gif(attrs) do
        {:ok, _browseable_gif} -> :ok
        {:error, _reason} -> :ok
      end
    end
  end


  defp format_duration(nil), do: "Unknown duration"
  defp format_duration(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    hours = div(total_seconds, 3600)
    minutes = div(rem(total_seconds, 3600), 60)
    seconds = rem(total_seconds, 60)

    if hours > 0 do
      "#{hours}:#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    else
      "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    end
  end

  defp format_timestamp(nil), do: "0:00"
  defp format_timestamp(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end

  defp encode_frame_image(nil), do: ""
  defp encode_frame_image(hex_data) when is_binary(hex_data) do
    case String.starts_with?(hex_data, "\\x") do
      true ->
        hex_string = String.slice(hex_data, 2..-1//1)
        case Base.decode16(hex_string, case: :lower) do
          {:ok, binary_data} -> Base.encode64(binary_data)
          :error -> ""
        end
      false ->
        Base.encode64(hex_data)
    end
  end

end
