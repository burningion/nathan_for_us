defmodule NathanForUsWeb.VideoSearchLive do
  @moduledoc """
  LiveView for searching video frames by text content in captions.
  
  Allows users to search for text across all video captions and displays
  matching frames as images loaded directly from the database.
  """
  
  use NathanForUsWeb, :live_view
  
  alias NathanForUs.Video

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
    selected_ids = socket.assigns.selected_video_ids
    
    new_selected_ids = 
      if video_id in selected_ids do
        List.delete(selected_ids, video_id)
      else
        [video_id | selected_ids]
      end

    {:noreply, assign(socket, :selected_video_ids, new_selected_ids)}
  end

  def handle_event("apply_video_filter", _params, socket) do
    search_mode = if Enum.empty?(socket.assigns.selected_video_ids), do: :global, else: :filtered
    
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


  @impl true
  def handle_info({:perform_search, term}, socket) do
    results = case socket.assigns.search_mode do
      :global -> 
        Video.search_frames_by_text_simple(term)
      :filtered -> 
        Video.search_frames_by_text_simple_filtered(term, socket.assigns.selected_video_ids)
    end
    
    socket =
      socket
      |> assign(:search_results, results)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 text-zinc-900 p-4 md:p-6 font-mono">
      <div class="max-w-5xl mx-auto">
        <.search_header search_term={@search_term} results_count={length(@search_results)} />
        
        <div class="space-y-4">
          <.search_interface 
            search_term={@search_term} 
            loading={@loading}
            videos={@videos}
            search_mode={@search_mode}
            selected_video_ids={@selected_video_ids}
          />
          
          <.search_results 
            :if={!@loading}
            search_results={@search_results}
            search_term={@search_term}
          />
          
          <.loading_state :if={@loading} search_term={@search_term} />
        </div>
        
        <.video_filter_modal 
          :if={@show_video_modal}
          videos={@videos}
          selected_video_ids={@selected_video_ids}
        />
        
        <.frame_sequence_modal 
          :if={@show_sequence_modal}
          frame_sequence={@frame_sequence}
          selected_frame_indices={@selected_frame_indices}
        />
      </div>
    </div>
    """
  end

  # Component functions

  # Search header component (captain's log style)
  defp search_header(assigns) do
    ~H"""
    <div class="mb-8 border-b border-zinc-300 pb-6">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 class="text-xl md:text-2xl font-bold text-blue-600 mb-1">Nathan Appearance Video Search</h1>
          <p class="text-zinc-600 text-sm">search a quote and find the frame(s) in which nathan said it in an interview</p>
        </div>
        <div class="text-left md:text-right text-xs text-zinc-500 space-y-1">
          <div>STATUS: <%= if @search_term != "", do: "SEARCHING", else: "READY" %></div>
          <div>RESULTS: <%= @results_count %></div>
          <div class="truncate max-w-xs">QUERY: "<%= @search_term %>"</div>
        </div>
      </div>
    </div>
    """
  end

  # Search interface component
  defp search_interface(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
      <div class="text-xs text-blue-600 uppercase mb-4 tracking-wide">SEARCH INTERFACE</div>
      
      <.form for={%{}} as={:search} phx-submit="search" class="mb-4">
        <div class="flex flex-col sm:flex-row gap-2">
          <input
            type="text"
            name="search[term]"
            value={@search_term}
            placeholder="Enter search query for spoken dialogue..."
            class="flex-1 border border-zinc-300 text-zinc-900 px-4 py-3 rounded font-mono focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
          />
          <button
            type="submit"
            disabled={@loading}
            class="bg-blue-600 hover:bg-blue-700 disabled:bg-zinc-400 text-white px-6 py-3 rounded font-mono text-sm transition-colors whitespace-nowrap"
          >
            <%= if @loading, do: "SEARCHING", else: "EXECUTE" %>
          </button>
          <button
            type="button"
            phx-click="toggle_video_modal"
            class="bg-zinc-600 hover:bg-zinc-700 text-white px-4 py-3 rounded font-mono text-sm transition-colors whitespace-nowrap flex items-center gap-2"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
            </svg>
            FILTER
          </button>
        </div>
      </.form>
      
      <!-- Quick search suggestions -->
      <div class="border-t border-zinc-200 pt-4">
        <div class="text-xs text-zinc-500 uppercase mb-2">QUICK QUERIES</div>
        <div class="flex flex-wrap gap-2">
          <.suggestion_button query="nathan" />
          <.suggestion_button query="business" />
          <.suggestion_button query="train" />
          <.suggestion_button query="conan" />
          <.suggestion_button query="rehearsal" />
        </div>
      </div>
      
      <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded text-blue-800 text-sm font-mono">
        <div class="text-xs text-blue-600 uppercase mb-1">SEARCH STATUS</div>
        <%= if @search_mode == :global do %>
          Searching across all <%= length(@videos) %> videos
        <% else %>
          <div class="flex items-center justify-between">
            <div>
              Filtering <%= length(@selected_video_ids) %> of <%= length(@videos) %> videos
            </div>
            <button
              phx-click="clear_video_filter"
              class="text-xs bg-blue-600 hover:bg-blue-700 text-white px-2 py-1 rounded transition-colors"
            >
              CLEAR FILTER
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Suggestion button component
  defp suggestion_button(assigns) do
    ~H"""
    <button
      phx-click="search"
      phx-value-search[term]={@query}
      class="px-3 py-1 bg-zinc-100 hover:bg-zinc-200 text-zinc-700 border border-zinc-300 rounded text-xs font-mono transition-colors"
    >
      "<%= @query %>"
    </button>
    """
  end

  # Search results component
  defp search_results(assigns) do
    ~H"""
    <%= if length(@search_results) > 0 do %>
      <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
        <div class="text-xs text-blue-600 uppercase mb-4 tracking-wide">SEARCH RESULTS - MOSAIC VIEW</div>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <%= for frame <- @search_results do %>
            <.frame_tile frame={frame} />
          <% end %>
        </div>
      </div>
    <% else %>
      <.empty_state :if={@search_term != ""} search_term={@search_term} />
    <% end %>
    """
  end

  # Individual frame tile component for mosaic view
  defp frame_tile(assigns) do
    ~H"""
    <div 
      class="border border-zinc-300 rounded-lg overflow-hidden hover:shadow-md transition-shadow bg-white cursor-pointer hover:border-blue-500"
      phx-click="show_frame_sequence"
      phx-value-frame_id={@frame.id}
    >
      <.frame_tile_image frame={@frame} />
      <.frame_tile_info frame={@frame} />
    </div>
    """
  end

  # Individual frame card component (kept for backwards compatibility)
  defp frame_card(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-4 hover:bg-zinc-50 transition-colors shadow-sm">
      <.frame_header frame={@frame} />
      <.frame_content frame={@frame} />
      <.frame_footer frame={@frame} />
    </div>
    """
  end

  # Frame header with timestamp and metadata
  defp frame_header(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-start justify-between mb-3 gap-2">
      <div class="text-zinc-500 text-xs">
        TIMESTAMP: <.frame_timestamp frame={@frame} />
      </div>
      <div class="text-left sm:text-right text-xs text-zinc-500 space-y-1">
        <div>FRAME: #<%= @frame.frame_number %></div>
        <%= if @frame.file_size do %>
          <div>SIZE: <%= format_file_size(@frame.file_size) %></div>
        <% end %>
      </div>
    </div>
    """
  end

  # Frame timestamp component
  defp frame_timestamp(assigns) do
    ~H"""
    <%= format_timestamp(@frame.timestamp_ms) %>
    """
  end

  # Frame content with image and caption
  defp frame_content(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row gap-4">
      <.frame_image frame={@frame} />
      <.frame_caption :if={Map.get(@frame, :caption_texts)} frame={@frame} />
    </div>
    """
  end

  # Frame image component
  defp frame_image(assigns) do
    ~H"""
    <div class="flex-shrink-0 w-full sm:w-32 h-48 sm:h-24">
      <%= if Map.get(@frame, :image_data) do %>
        <img
          id={"frame-#{@frame.id}"}
          src={"data:image/jpeg;base64,#{encode_image_data(@frame.image_data)}"}
          alt={"Frame at " <> format_timestamp(@frame.timestamp_ms)}
          class="w-full h-full object-cover rounded border border-zinc-300"
        />
      <% else %>
        <div class="w-full h-full flex items-center justify-center bg-zinc-100 border border-zinc-300 rounded text-zinc-400">
          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        </div>
      <% end %>
    </div>
    """
  end

  # Frame caption component
  defp frame_caption(assigns) do
    ~H"""
    <div class="flex-1">
      <div class="text-xs text-blue-600 uppercase mb-2">SPOKEN DIALOGUE</div>
      <div class="text-zinc-800 text-sm leading-relaxed pl-4 border-l-2 border-blue-600">
        "<%= @frame.caption_texts %>"
      </div>
    </div>
    """
  end

  # Frame footer component
  defp frame_footer(assigns) do
    ~H"""
    <div class="mt-3 pt-3 border-t border-zinc-200">
      <div class="text-xs text-zinc-500">
        ID: <%= String.slice(to_string(@frame.id), 0, 8) %>
      </div>
    </div>
    """
  end

  # Loading state component
  defp loading_state(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-8 text-center shadow-sm">
      <div class="text-blue-600 text-lg mb-2 font-mono">
        PROCESSING QUERY
      </div>
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
      <p class="text-zinc-600 text-sm font-mono">
        Scanning video database for: "<%= @search_term %>"
      </p>
    </div>
    """
  end

  # Empty state component
  defp empty_state(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-8 text-center shadow-sm">
      <div class="text-blue-600 text-lg mb-2 font-mono">
        NO MATCHES FOUND
      </div>
      <p class="text-zinc-600 text-sm mb-4">
        No video frames found containing "<%= @search_term %>"
      </p>
      <p class="text-zinc-500 text-xs font-mono">
        Try different keywords or check the quick queries above
      </p>
    </div>
    """
  end


  # Frame tile image component for mosaic view
  defp frame_tile_image(assigns) do
    ~H"""
    <div class="aspect-video bg-zinc-100 relative">
      <%= if Map.get(@frame, :image_data) do %>
        <img
          id={"tile-frame-#{@frame.id}"}
          src={"data:image/jpeg;base64,#{encode_image_data(@frame.image_data)}"}
          alt={"Frame at " <> format_timestamp(@frame.timestamp_ms)}
          class="w-full h-full object-cover"
        />
      <% else %>
        <div class="w-full h-full flex items-center justify-center text-zinc-400">
          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        </div>
      <% end %>
      
      <!-- Timestamp overlay -->
      <div class="absolute bottom-1 right-1 bg-black/70 text-white px-1 py-0.5 rounded text-xs font-mono">
        <%= format_timestamp(@frame.timestamp_ms) %>
      </div>
    </div>
    """
  end

  # Frame tile info component for mosaic view
  defp frame_tile_info(assigns) do
    ~H"""
    <div class="p-2">
      <%= if Map.get(@frame, :video_title) do %>
        <div class="text-blue-600 text-xs font-mono font-bold mb-1 truncate">
          <%= String.slice(@frame.video_title, 0..40) %><%= if String.length(@frame.video_title) > 40, do: "..." %>
        </div>
      <% end %>
      
      <div class="flex items-center justify-between mb-2">
        <span class="text-zinc-500 text-xs font-mono">FRAME #<%= @frame.frame_number %></span>
        <%= if @frame.file_size do %>
          <span class="text-zinc-400 text-xs font-mono"><%= format_file_size(@frame.file_size) %></span>
        <% end %>
      </div>
      
      <%= if Map.get(@frame, :caption_texts) do %>
        <div class="border-l-2 border-blue-600 pl-2">
          <div class="text-zinc-800 text-xs leading-relaxed line-clamp-3">
            "<%= @frame.caption_texts %>"
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Video filter modal component
  defp video_filter_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" phx-click="toggle_video_modal">
      <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto" phx-click-away="toggle_video_modal">
        <div class="p-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-bold text-zinc-900 font-mono">SELECT VIDEOS TO SEARCH</h2>
            <button
              phx-click="toggle_video_modal"
              class="text-zinc-500 hover:text-zinc-700 transition-colors"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          
          <div class="space-y-3 mb-6">
            <%= for video <- @videos do %>
              <div class={[
                "p-3 border rounded cursor-pointer transition-colors font-mono text-sm",
                if(video.id in @selected_video_ids, do: "border-blue-500 bg-blue-50 text-blue-900", else: "border-zinc-300 hover:border-zinc-400 text-zinc-700")
              ]}
              phx-click="toggle_video_selection"
              phx-value-video_id={video.id}>
                <div class="flex items-center gap-3">
                  <div class={[
                    "w-5 h-5 border-2 rounded flex items-center justify-center",
                    if(video.id in @selected_video_ids, do: "border-blue-500 bg-blue-500", else: "border-zinc-300")
                  ]}>
                    <%= if video.id in @selected_video_ids do %>
                      <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                      </svg>
                    <% end %>
                  </div>
                  <div class="flex-1">
                    <div class="font-bold truncate"><%= video.title %></div>
                    <div class="text-xs text-zinc-500 mt-1">
                      <%= if video.frame_count, do: "#{video.frame_count} frames", else: "Processing..." %> | 
                      <%= if video.duration_ms, do: format_timestamp(video.duration_ms), else: "Unknown duration" %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          
          <div class="flex gap-3 justify-end">
            <button
              phx-click="toggle_video_modal"
              class="px-4 py-2 border border-zinc-300 text-zinc-700 rounded font-mono text-sm hover:bg-zinc-50 transition-colors"
            >
              CANCEL
            </button>
            <button
              phx-click="apply_video_filter"
              class="px-4 py-2 bg-blue-600 text-white rounded font-mono text-sm hover:bg-blue-700 transition-colors"
            >
              APPLY FILTER (<%= length(@selected_video_ids) %> selected)
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp video_status_class("pending"), do: "bg-yellow-100 text-yellow-800 border border-yellow-300"
  defp video_status_class("processing"), do: "bg-blue-100 text-blue-800 border border-blue-300" 
  defp video_status_class("completed"), do: "bg-green-100 text-green-800 border border-green-300"
  defp video_status_class("failed"), do: "bg-red-100 text-red-800 border border-red-300"
  defp video_status_class(_), do: "bg-zinc-100 text-zinc-800 border border-zinc-300"

  defp format_timestamp(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
  defp format_timestamp(_), do: "0:00"

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      true -> "#{bytes} B"
    end
  end
  defp format_file_size(_), do: "Unknown"

  defp encode_image_data(nil), do: ""
  defp encode_image_data(hex_data) when is_binary(hex_data) do
    # The image data is stored as hex-encoded string starting with \x
    # We need to decode it from hex, then encode to base64
    case String.starts_with?(hex_data, "\\x") do
      true ->
        # Remove the \x prefix and decode from hex
        hex_string = String.slice(hex_data, 2..-1//1)
        case Base.decode16(hex_string, case: :lower) do
          {:ok, binary_data} -> Base.encode64(binary_data)
          :error -> ""
        end
      false ->
        # Already binary data, encode directly
        Base.encode64(hex_data)
    end
  end

  defp get_selected_frames_captions(frame_sequence, selected_frame_indices) do
    if frame_sequence && Map.has_key?(frame_sequence, :sequence_captions) do
      # Get selected frames
      selected_frames = selected_frame_indices
      |> Enum.map(fn index -> 
        Enum.at(frame_sequence.sequence_frames, index)
      end)
      |> Enum.reject(&is_nil/1)
      
      # Collect all captions from selected frames
      all_captions = selected_frames
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

  # Frame sequence modal component
  defp frame_sequence_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50" phx-click="close_sequence_modal">
      <div class="bg-white rounded-lg shadow-xl max-w-7xl w-full mx-4 max-h-[90vh] overflow-y-auto" phx-click-away="close_sequence_modal">
        <div class="p-6">
          <!-- Modal Header -->
          <div class="flex items-center justify-between mb-6">
            <div>
              <h2 class="text-xl font-bold text-zinc-900 font-mono">FRAME SEQUENCE VIEWER</h2>
              <p class="text-sm text-zinc-600 font-mono mt-1">
                Frame #<%= @frame_sequence.target_frame.frame_number %> with surrounding frames (± 5)
              </p>
            </div>
            <button
              phx-click="close_sequence_modal"
              class="text-zinc-500 hover:text-zinc-700 transition-colors"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          
          <!-- Target Frame Info -->
          <div class="mb-6 p-4 bg-blue-50 border border-blue-200 rounded font-mono text-sm">
            <div class="text-blue-600 uppercase mb-2">TARGET FRAME CONTEXT</div>
            <div class="text-blue-900">
              <div class="mb-1">Timestamp: <%= format_timestamp(@frame_sequence.target_frame.timestamp_ms) %></div>
              <%= if @frame_sequence.target_captions != "" do %>
                <div class="border-l-2 border-blue-600 pl-3 mt-2">
                  "<%= @frame_sequence.target_captions %>"
                </div>
              <% end %>
            </div>
          </div>
          
          <!-- Animated GIF Preview -->
          <div class="mb-8 bg-zinc-900 rounded-lg p-6">
            <div class="text-white uppercase mb-4 font-mono text-sm flex items-center justify-between">
              <span>🎬 ANIMATED PREVIEW</span>
              <span class="text-xs text-zinc-400">
                Animating <%= length(@selected_frame_indices) %> of <%= length(@frame_sequence.sequence_frames) %> frames
              </span>
            </div>
            
            <!-- Selection Controls -->
            <div class="mb-4 p-3 bg-zinc-800 rounded border border-zinc-700">
              <div class="text-zinc-300 text-xs uppercase mb-2">FRAME SELECTION CONTROLS</div>
              <div class="flex items-center gap-4">
                <button 
                  phx-click="select_all_frames"
                  class="bg-blue-600 hover:bg-blue-700 text-white text-xs px-3 py-1 rounded"
                >
                  SELECT ALL
                </button>
                <button 
                  phx-click="deselect_all_frames"
                  class="bg-red-600 hover:bg-red-700 text-white text-xs px-3 py-1 rounded"
                >
                  DESELECT ALL
                </button>
                <div class="text-zinc-400 text-xs ml-4">
                  Click individual frames below to toggle them in/out of animation
                </div>
              </div>
            </div>
            
            <div class="flex justify-center">
              <div class="relative bg-black rounded-lg overflow-hidden">
                <div 
                  id={"animation-container-#{@frame_sequence.target_frame.id}"}
                  class="w-80 h-48 relative"
                  phx-hook="FrameAnimator"
                  data-frames={Jason.encode!(Enum.map(@frame_sequence.sequence_frames, fn frame -> 
                    if Map.get(frame, :image_data) do
                      "data:image/jpeg;base64,#{encode_image_data(frame.image_data)}"
                    else
                      nil
                    end
                  end))}
                  data-selected-indices={Jason.encode!(@selected_frame_indices)}
                >
                  <%= for {frame, index} <- Enum.with_index(@frame_sequence.sequence_frames) do %>
                    <%= if Map.get(frame, :image_data) do %>
                      <img
                        id={"anim-frame-#{frame.id}"}
                        src={"data:image/jpeg;base64,#{encode_image_data(frame.image_data)}"}
                        alt={"Frame ##{frame.frame_number}"}
                        class={[
                          "absolute inset-0 w-full h-full object-cover transition-opacity duration-50",
                          if(index == Enum.at(@selected_frame_indices, 0, 0), do: "opacity-100", else: "opacity-0")
                        ]}
                        data-frame-index={index}
                      />
                    <% end %>
                  <% end %>
                  
                  <!-- Animation overlay info -->
                  <div class="absolute bottom-2 left-2 bg-black/70 text-white px-2 py-1 rounded text-xs font-mono">
                    LOOP: 200ms/frame
                  </div>
                  
                  <!-- Frame counter -->
                  <div id={"frame-counter-#{@frame_sequence.target_frame.id}"} class="absolute bottom-2 right-2 bg-black/70 text-white px-2 py-1 rounded text-xs font-mono">
                    1/<%= length(@selected_frame_indices) %>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Selected Frames Captions -->
            <div class="mt-6 p-4 bg-zinc-800 rounded border border-zinc-700">
              <div class="text-zinc-300 text-xs uppercase mb-3 font-mono">🎬 SELECTED FRAMES DIALOGUE</div>
              <div class="text-zinc-100 text-sm leading-relaxed font-mono">
                <%= get_selected_frames_captions(@frame_sequence, @selected_frame_indices) %>
              </div>
            </div>
            
            <div class="text-center mt-4">
              <p class="text-zinc-400 text-sm font-mono">Click frames below to control which ones animate</p>
            </div>
          </div>
          
          <!-- Frame Sequence Grid -->
          <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3">
            <%= for {frame, index} <- Enum.with_index(@frame_sequence.sequence_frames) do %>
              <div class={[
                "border rounded-lg overflow-hidden cursor-pointer hover:shadow-lg transition-all",
                cond do
                  frame.id == @frame_sequence.target_frame.id and index in @selected_frame_indices -> 
                    "border-blue-500 border-2 bg-blue-50 ring-2 ring-blue-200"
                  frame.id == @frame_sequence.target_frame.id -> 
                    "border-blue-300 border-2 bg-blue-25 ring-1 ring-blue-100 opacity-60"
                  index in @selected_frame_indices -> 
                    "border-blue-500 border-2 bg-blue-50"
                  true -> 
                    "border-zinc-300 hover:border-zinc-400 opacity-60"
                end
              ]}
              phx-click="toggle_frame_selection"
              phx-value-frame_index={index}
              title={if index in @selected_frame_indices, do: "Click to remove from animation", else: "Click to add to animation"}
              >
                <!-- Frame Image -->
                <div class="aspect-video bg-zinc-100 relative">
                  <%= if Map.get(frame, :image_data) do %>
                    <img
                      src={"data:image/jpeg;base64,#{encode_image_data(frame.image_data)}"}
                      alt={"Frame ##{frame.frame_number}"}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center text-zinc-400">
                      <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    </div>
                  <% end %>
                  
                  <!-- Frame number overlay -->
                  <div class={[
                    "absolute bottom-1 right-1 px-1 py-0.5 rounded text-xs font-mono",
                    if(frame.id == @frame_sequence.target_frame.id, do: "bg-blue-600 text-white", else: "bg-black/70 text-white")
                  ]}>
                    #<%= frame.frame_number %>
                  </div>
                  
                  <!-- Target frame indicator -->
                  <%= if frame.id == @frame_sequence.target_frame.id do %>
                    <div class="absolute top-1 left-1 bg-blue-600 text-white px-1 py-0.5 rounded text-xs font-mono">
                      TARGET
                    </div>
                  <% end %>
                  
                  <!-- Selection indicator -->
                  <%= if index in @selected_frame_indices do %>
                    <div class="absolute top-1 right-1 bg-blue-500 text-white rounded-full w-5 h-5 flex items-center justify-center">
                      <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                      </svg>
                    </div>
                  <% else %>
                    <div class="absolute top-1 right-1 bg-zinc-400 text-white rounded-full w-5 h-5 flex items-center justify-center opacity-50">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </div>
                  <% end %>
                </div>
                
                <!-- Frame Info -->
                <div class="p-2">
                  <div class="text-xs text-zinc-500 font-mono text-center">
                    <%= format_timestamp(frame.timestamp_ms) %>
                  </div>
                  <%= if frame.file_size do %>
                    <div class="text-xs text-zinc-400 font-mono text-center">
                      <%= format_file_size(frame.file_size) %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
          
          <!-- Sequence Info -->
          <div class="mt-6 p-4 bg-zinc-50 border border-zinc-200 rounded font-mono text-sm">
            <div class="text-zinc-600 uppercase mb-2">SEQUENCE INFORMATION</div>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-zinc-700">
              <div>
                <div class="text-xs text-zinc-500">FRAMES LOADED</div>
                <div><%= @frame_sequence.sequence_info.total_frames %></div>
              </div>
              <div>
                <div class="text-xs text-zinc-500">FRAME RANGE</div>
                <div>#<%= @frame_sequence.sequence_info.start_frame_number %>-<%= @frame_sequence.sequence_info.end_frame_number %></div>
              </div>
              <div>
                <div class="text-xs text-zinc-500">TARGET FRAME</div>
                <div>#<%= @frame_sequence.sequence_info.target_frame_number %></div>
              </div>
              <div>
                <div class="text-xs text-zinc-500">ANIMATION READY</div>
                <div class="text-blue-600">✓ YES</div>
              </div>
            </div>
          </div>
          
          <!-- Animation Status -->
          <div class="mt-4 p-3 bg-green-50 border border-green-200 rounded text-green-800 text-sm font-mono">
            ✅ Animation active - <%= length(@selected_frame_indices) %> of <%= @frame_sequence.sequence_info.total_frames %> frames cycling at 200ms intervals (5fps simulation)
          </div>
          
          <!-- Frame Legend -->
          <div class="mt-4 p-3 bg-zinc-50 border border-zinc-200 rounded text-zinc-700 text-sm font-mono">
            <div class="text-zinc-600 uppercase mb-2 text-xs">FRAME LEGEND</div>
            <div class="flex flex-wrap gap-4 text-xs">
              <div class="flex items-center gap-2">
                <div class="w-4 h-4 border-2 border-blue-500 bg-blue-50 rounded"></div>
                <span>Target Frame</span>
              </div>
              <div class="flex items-center gap-2">
                <div class="w-4 h-4 border-2 border-blue-500 bg-blue-50 rounded flex items-center justify-center">
                  <svg class="w-2 h-2 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                  </svg>
                </div>
                <span>Selected for Animation</span>
              </div>
              <div class="flex items-center gap-2">
                <div class="w-4 h-4 border border-zinc-300 bg-white rounded opacity-60"></div>
                <span>Not Selected</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end