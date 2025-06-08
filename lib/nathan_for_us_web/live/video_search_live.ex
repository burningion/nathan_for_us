defmodule NathanForUsWeb.VideoSearchLive do
  @moduledoc """
  LiveView for searching video frames by text content in captions.
  
  Allows users to search for text across all video captions and displays
  matching frames as images loaded directly from the database.
  """
  
  use NathanForUsWeb, :live_view
  
  alias NathanForUs.Video

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:loading, false)
      |> assign(:videos, Video.list_videos())

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


  @impl true
  def handle_info({:perform_search, term}, socket) do
    results = Video.search_frames_by_text_simple(term)
    
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
          />
          
          <.search_results 
            :if={!@loading}
            search_results={@search_results}
            search_term={@search_term}
          />
          
          <.loading_state :if={@loading} search_term={@search_term} />
          
          <.video_status_panel videos={@videos} />
        </div>
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
          <h1 class="text-xl md:text-2xl font-bold text-blue-600 mb-1">VIDEO FRAME SEARCH</h1>
          <p class="text-zinc-600 text-sm">Deep archive analysis system for Nathan Fielder content</p>
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
        </div>
      </.form>
      
      <!-- Quick search suggestions -->
      <div class="border-t border-zinc-200 pt-4">
        <div class="text-xs text-zinc-500 uppercase mb-2">QUICK QUERIES</div>
        <div class="flex flex-wrap gap-2">
          <.suggestion_button query="train" />
          <.suggestion_button query="choo choo" />
          <.suggestion_button query="sound" />
          <.suggestion_button query="business" />
        </div>
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
    <div class="border border-zinc-300 rounded-lg overflow-hidden hover:shadow-md transition-shadow bg-white">
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

  # Video status panel component
  defp video_status_panel(assigns) do
    ~H"""
    <details class="bg-white border border-zinc-300 rounded-lg shadow-sm">
      <summary class="px-6 py-4 cursor-pointer text-zinc-700 hover:text-blue-600 font-mono text-sm border-b border-zinc-200">
        SYSTEM STATUS: VIDEO PROCESSING
      </summary>
      <div class="p-6">
        <div class="space-y-3">
          <%= for video <- @videos do %>
            <.video_status_item video={video} />
          <% end %>
        </div>
      </div>
    </details>
    """
  end

  # Individual video status item
  defp video_status_item(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-center justify-between py-2 border-b border-zinc-100 last:border-b-0 gap-2">
      <div class="flex-1 min-w-0">
        <div class="text-zinc-900 text-sm font-mono truncate"><%= @video.title %></div>
        <div class="flex flex-wrap items-center gap-3 mt-1">
          <span class={[
            "px-2 py-1 text-xs rounded font-mono",
            video_status_class(@video.status)
          ]}>
            <%= String.upcase(@video.status) %>
          </span>
          <%= if @video.frame_count do %>
            <span class="text-zinc-500 text-xs font-mono"><%= @video.frame_count %> frames</span>
          <% end %>
        </div>
      </div>
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
        hex_string = String.slice(hex_data, 2..-1)
        case Base.decode16(hex_string, case: :lower) do
          {:ok, binary_data} -> Base.encode64(binary_data)
          :error -> ""
        end
      false ->
        # Already binary data, encode directly
        Base.encode64(hex_data)
    end
  end
end