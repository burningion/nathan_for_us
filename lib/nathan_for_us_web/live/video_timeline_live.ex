defmodule NathanForUsWeb.VideoTimelineLive do
  @moduledoc """
  Timeline-based video browser LiveView.
  
  Provides an intuitive timeline interface where users can drag to navigate
  through the entire video, see frame previews, and create GIFs from any section.
  """
  
  use NathanForUsWeb, :live_view
  
  alias NathanForUs.Repo
  alias NathanForUs.Video.VideoFrame
  alias NathanForUsWeb.Components.VideoTimeline.{
    TimelinePlayer,
    FrameDisplay,
    TimelineControls,
    CaptionSearch
  }
  
  require Logger
  
  @default_frames_per_page 50
  
  def mount(%{"video_id" => video_id}, _session, socket) do
    try do
      video_id = String.to_integer(video_id)
      
      case NathanForUs.Video.get_video(video_id) do
        {:error, :not_found} ->
          socket =
            socket
            |> put_flash(:error, "Video not found")
            |> redirect(to: ~p"/video-search")
          
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
          
          # Load initial frames
          send(self(), {:load_frames_at_position, 0.0})
          
          {:ok, socket}
      end
    rescue
      ArgumentError ->
        socket =
          socket
          |> put_flash(:error, "Invalid video ID")
          |> redirect(to: ~p"/video-search")
        
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
      
      # If we're in caption filtered state, clicking a frame should show context
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
            |> put_flash(:info, "Showing context around frame ##{clicked_frame.frame_number} (#{length(context_frames)} frames)")
          
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
        
        socket = assign(socket, :selected_frame_indices, new_selected)
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
      
      socket = assign(socket, :selected_frame_indices, new_selected)
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
  
  def handle_event("create_sequence_from_selection", _params, socket) do
    case socket.assigns.selected_frame_indices do
      [] ->
        socket = put_flash(socket, :error, "No frames selected")
        {:noreply, socket}
      
      indices ->
        # Get the selected frames
        selected_frames = 
          indices
          |> Enum.map(&Enum.at(socket.assigns.current_frames, &1))
          |> Enum.reject(&is_nil/1)
        
        case selected_frames do
          [] ->
            socket = put_flash(socket, :error, "Selected frames not found")
            {:noreply, socket}
          
          frames ->
            # Redirect to video search with the first frame and all frame IDs
            first_frame = List.first(frames)
            frame_ids = Enum.map(frames, & &1.id)
            path = ~p"/video-search?frame=#{first_frame.id}&frame_ids=#{Enum.join(frame_ids, ",")}"
            
            socket = redirect(socket, to: path)
            {:noreply, socket}
        end
    end
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
        |> put_flash(:info, "Found #{length(filtered_frames)} frames with \"#{term}\"")
      
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
        |> put_flash(:info, "Added #{expand_count} frames to the left")
      
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
        |> put_flash(:info, "Added #{expand_count} frames to the right")
      
      {:noreply, socket}
    else
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
              navigate={~p"/video-search"} 
              class="text-blue-400 hover:text-blue-300 font-mono text-sm"
            >
              ← Back to Search
            </.link>
            
            <%= if length(@selected_frame_indices) > 0 do %>
              <button
                phx-click="create_sequence_from_selection"
                class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded font-mono text-sm"
              >
                Create Sequence (<%= length(@selected_frame_indices) %> frames)
              </button>
            <% end %>
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
      
      <!-- Timeline Controls -->
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
                  <div class="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center font-bold text-sm">3</div>
                  <div>
                    <h3 class="text-lg font-semibold mb-2 text-white">Multi-Select Frames</h3>
                    <p class="leading-relaxed">Click on individual frames to select them (they'll show a blue border). Hold Shift and drag to select multiple frames at once. You can also click individual frames while holding Ctrl/Cmd to add them to your selection.</p>
                  </div>
                </div>
                
                <div class="flex items-start gap-4">
                  <div class="bg-blue-600 text-white rounded-full w-8 h-8 flex items-center justify-center font-bold text-sm">4</div>
                  <div>
                    <h3 class="text-lg font-semibold mb-2 text-white">Create Sequences</h3>
                    <p class="leading-relaxed">Once you have frames selected, click the "Create Sequence" button to jump to the main app where you can generate GIFs, analyze the frames, or perform other operations on your selection.</p>
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