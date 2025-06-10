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
      |> assign(:animation_speed, 150)
      |> assign(:expanded_videos, MapSet.new())  # Track which videos are expanded
      |> assign(:show_welcome_modal, show_welcome_modal)
      |> assign(:gif_generation_status, nil)
      |> assign(:generated_gif_data, nil)

    {:ok, socket}
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

      {:noreply, assign(socket, :selected_video_ids, new_selected_ids)}
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
      
      socket = assign(socket, :selected_frame_indices, new_selected)
      {:noreply, socket}
    rescue
      ArgumentError ->
        socket = put_flash(socket, :error, "Invalid frame index")
        {:noreply, socket}
    end
  end

  def handle_event("select_all_frames", _params, socket) do
    all_frame_indices = 0..(length(socket.assigns.frame_sequence.sequence_frames) - 1) |> Enum.to_list()
    socket = assign(socket, :selected_frame_indices, all_frame_indices)
    {:noreply, socket}
  end

  def handle_event("deselect_all_frames", _params, socket) do
    socket = assign(socket, :selected_frame_indices, [])
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
            updated_indices = Enum.map(socket.assigns.selected_frame_indices, fn index -> index + 1 end)
            Logger.info("Updated selected indices: #{inspect(updated_indices)}")
            
            socket =
              socket
              |> assign(:frame_sequence, expanded_sequence)
              |> assign(:selected_frame_indices, updated_indices)
            
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
            socket = assign(socket, :frame_sequence, expanded_sequence)
            {:noreply, socket}
          
          {:error, reason} ->
            Logger.info("Expand forward failed: #{inspect(reason)}")
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
          animation_speed={@animation_speed}
          gif_generation_status={@gif_generation_status}
          generated_gif_data={@generated_gif_data}
        />
      </div>
    </div>

    """
  end

end