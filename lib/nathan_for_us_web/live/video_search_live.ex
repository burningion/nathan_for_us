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
  def mount(_params, _session, socket) do
    videos = Video.list_videos()

    socket =
      socket
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

  def handle_event("toggle_video_modal", _params, socket) do
    {:noreply, assign(socket, :show_video_modal, !socket.assigns.show_video_modal)}
  end

  def handle_event("toggle_video_selection", %{"video_id" => video_id}, socket) do
    video_id = String.to_integer(video_id)
    current_selected = socket.assigns.selected_video_ids
    
    new_selected_ids = Search.update_video_filter(current_selected, video_id)

    {:noreply, assign(socket, :selected_video_ids, new_selected_ids)}
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

  def handle_event("process_video", %{"video_path" => video_path}, socket) do
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
  end

  def handle_event("show_frame_sequence", %{"frame_id" => frame_id}, socket) do
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
  end

  def handle_event("close_sequence_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_sequence_modal, false)
      |> assign(:frame_sequence, nil)
      |> assign(:selected_frame_indices, [])
    
    {:noreply, socket}
  end

  def handle_event("toggle_frame_selection", %{"frame_index" => frame_index_str}, socket) do
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

  def handle_event("autocomplete_search", %{"search" => %{"term" => term}}, socket) do
    if String.length(term) >= 3 do
      suggestions = Search.get_autocomplete_suggestions(term, socket.assigns.search_mode, socket.assigns.selected_video_ids)
      
      socket =
        socket
        |> assign(:search_term, term)
        |> assign(:autocomplete_suggestions, suggestions)
        |> assign(:show_autocomplete, true)
      
      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:search_term, term)
        |> assign(:autocomplete_suggestions, [])
        |> assign(:show_autocomplete, false)
      
      {:noreply, socket}
    end
  end

  def handle_event("select_suggestion", %{"suggestion" => suggestion}, socket) do
    socket =
      socket
      |> assign(:search_term, suggestion)
      |> assign(:show_autocomplete, false)
      |> assign(:autocomplete_suggestions, [])

    {:noreply, socket}
  end

  def handle_event("hide_autocomplete", _params, socket) do
    socket = assign(socket, :show_autocomplete, false)
    {:noreply, socket}
  end


  @impl true
  def handle_info({:perform_search, term}, socket) do
    case Search.search_frames(term, socket.assigns.search_mode, socket.assigns.selected_video_ids) do
      {:ok, results} ->
        socket =
          socket
          |> assign(:search_results, results)
          |> assign(:loading, false)

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 text-zinc-900 p-4 md:p-6 font-mono">
      <div class="max-w-5xl mx-auto">
        <SearchHeader.search_header search_term={@search_term} results_count={length(@search_results)} />
        
        <div class="space-y-4">
          <SearchInterface.search_interface 
            search_term={@search_term} 
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
        />
      </div>
    </div>
    """
  end

end