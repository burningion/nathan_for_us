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
    <div class="min-h-screen bg-slate-900 text-slate-100">
      <!-- Hero Section -->
      <div class="bg-gradient-to-r from-slate-800 to-slate-900 border-b border-slate-700">
        <div class="max-w-6xl mx-auto px-6 py-8">
          <div class="text-center">
            <h1 class="text-4xl font-bold text-white mb-3">
              Video Frame Search
            </h1>
            <p class="text-slate-400 text-lg">
              Search through video content using spoken dialogue and captions
            </p>
          </div>
        </div>
      </div>

      <!-- Main Content -->
      <div class="max-w-6xl mx-auto px-6 py-8">
        
        <!-- Search Section -->
        <div class="mb-8">
          <.form for={%{}} as={:search} phx-submit="search" class="max-w-2xl mx-auto">
            <div class="relative">
              <input
                type="text"
                name="search[term]"
                value={@search_term}
                placeholder="Search for spoken words or phrases..."
                class="w-full bg-slate-800 border border-slate-600 text-slate-100 px-6 py-4 pr-24 rounded-lg focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 text-lg"
              />
              <button
                type="submit"
                disabled={@loading}
                class="absolute right-2 top-2 bottom-2 bg-blue-600 hover:bg-blue-700 disabled:bg-slate-600 text-white px-6 rounded-md font-medium transition-colors"
              >
                <%= if @loading, do: "Searching...", else: "Search" %>
              </button>
            </div>
          </.form>
          
          <!-- Search suggestions -->
          <div class="max-w-2xl mx-auto mt-4 text-center">
            <p class="text-slate-500 text-sm mb-2">Try searching for:</p>
            <div class="flex flex-wrap justify-center gap-2">
              <button
                phx-click="search"
                phx-value-search[term]="train"
                class="px-3 py-1 bg-slate-700 hover:bg-slate-600 text-slate-300 rounded-full text-sm transition-colors"
              >
                "train"
              </button>
              <button
                phx-click="search"
                phx-value-search[term]="choo choo"
                class="px-3 py-1 bg-slate-700 hover:bg-slate-600 text-slate-300 rounded-full text-sm transition-colors"
              >
                "choo choo"
              </button>
              <button
                phx-click="search"
                phx-value-search[term]="sound"
                class="px-3 py-1 bg-slate-700 hover:bg-slate-600 text-slate-300 rounded-full text-sm transition-colors"
              >
                "sound"
              </button>
            </div>
          </div>
        </div>

        <!-- Results Section -->
        <%= if @loading do %>
          <div class="text-center py-16">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
            <div class="text-slate-400 text-lg">Searching video captions...</div>
            <div class="text-slate-500 text-sm mt-2">Looking for "<%= @search_term %>"</div>
          </div>
        <% else %>
          <%= if length(@search_results) > 0 do %>
            <!-- Results header -->
            <div class="mb-6">
              <h2 class="text-2xl font-semibold text-white mb-2">
                Search Results
              </h2>
              <p class="text-slate-400">
                Found <%= length(@search_results) %> frames matching "<%= @search_term %>"
              </p>
            </div>
            
            <!-- Results grid -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for frame <- @search_results do %>
                <div class="bg-slate-800 rounded-lg overflow-hidden border border-slate-700 hover:border-slate-600 transition-colors">
                  <!-- Frame image -->
                  <div class="aspect-video bg-slate-900 relative group">
                    <%= if Map.get(frame, :image_data) do %>
                      <img
                        id={"frame-#{frame.id}"}
                        src={"data:image/jpeg;base64,#{Base.encode64(frame.image_data)}"}
                        alt={"Frame at " <> format_timestamp(frame.timestamp_ms)}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <div class="w-full h-full flex items-center justify-center text-slate-500">
                        <svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                      </div>
                    <% end %>
                    
                    <!-- Timestamp overlay -->
                    <div class="absolute bottom-2 right-2 bg-black/70 text-white px-2 py-1 rounded text-xs font-mono">
                      <%= format_timestamp(frame.timestamp_ms) %>
                    </div>
                  </div>
                  
                  <!-- Frame details -->
                  <div class="p-4">
                    <div class="flex items-center justify-between mb-3">
                      <span class="text-slate-400 text-sm">Frame #<%= frame.frame_number %></span>
                      <%= if frame.file_size do %>
                        <span class="text-slate-500 text-xs"><%= format_file_size(frame.file_size) %></span>
                      <% end %>
                    </div>
                    
                    <%= if Map.get(frame, :caption_texts) do %>
                      <div class="bg-slate-900 border border-slate-700 rounded-lg p-3">
                        <div class="text-slate-400 text-xs uppercase tracking-wide mb-1">Spoken dialogue</div>
                        <p class="text-slate-200 text-sm leading-relaxed">
                          "<%= frame.caption_texts %>"
                        </p>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <%= if @search_term != "" do %>
              <div class="text-center py-16">
                <div class="w-16 h-16 mx-auto mb-4 text-slate-600">
                  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>
                <h3 class="text-xl font-medium text-slate-300 mb-2">No results found</h3>
                <p class="text-slate-500 mb-4">
                  No video frames found containing "<%= @search_term %>"
                </p>
                <p class="text-slate-600 text-sm">
                  Try different keywords or check the suggested searches above
                </p>
              </div>
            <% end %>
          <% end %>
        <% end %>

        <!-- Video status (collapsed by default) -->
        <details class="mt-12 bg-slate-800 border border-slate-700 rounded-lg">
          <summary class="px-6 py-4 cursor-pointer text-slate-300 hover:text-white font-medium">
            Video Processing Status
          </summary>
          <div class="px-6 pb-6 border-t border-slate-700">
            <div class="space-y-3 mt-4">
              <%= for video <- @videos do %>
                <div class="flex items-center justify-between py-2">
                  <div class="flex-1">
                    <div class="text-slate-200 text-sm truncate"><%= video.title %></div>
                    <div class="flex items-center gap-2 mt-1">
                      <span class={[
                        "px-2 py-1 text-xs rounded-full font-medium",
                        status_class(video.status)
                      ]}>
                        <%= String.upcase(video.status) %>
                      </span>
                      <%= if video.frame_count do %>
                        <span class="text-slate-500 text-xs"><%= video.frame_count %> frames</span>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </details>
      </div>
    </div>

    """
  end

  # Helper functions

  defp status_class("pending"), do: "bg-yellow-500 text-yellow-900"
  defp status_class("processing"), do: "bg-blue-500 text-blue-900" 
  defp status_class("completed"), do: "bg-green-500 text-green-900"
  defp status_class("failed"), do: "bg-red-500 text-red-900"
  defp status_class(_), do: "bg-slate-500 text-slate-900"

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
end