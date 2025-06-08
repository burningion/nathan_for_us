defmodule NathanForUsWeb.VideoSearchLive do
  @moduledoc """
  LiveView for searching video frames by text content in captions.
  
  Allows users to search for text across all video captions and displays
  matching frames as images.
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
    <div class="min-h-screen bg-gray-900 text-green-400 font-mono">
      <div class="container mx-auto px-4 py-8">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-green-300 mb-2">
            NATHAN FOR US - VIDEO SEARCH
          </h1>
          <p class="text-green-500">
            Search through video frames using caption text
          </p>
        </div>

        <!-- Video Processing Status -->
        <div class="mb-8 bg-gray-800 border border-green-600 rounded p-4">
          <h2 class="text-xl font-semibold text-green-300 mb-4">Video Processing Status</h2>
          
          <div class="space-y-2">
            <%= for video <- @videos do %>
              <div class="flex items-center justify-between py-2 border-b border-gray-700">
                <div class="flex-1">
                  <span class="text-green-400"><%= video.title %></span>
                  <span class={[
                    "ml-2 px-2 py-1 text-xs rounded",
                    status_class(video.status)
                  ]}>
                    <%= String.upcase(video.status) %>
                  </span>
                </div>
                <%= if video.status == "completed" and video.frame_count do %>
                  <span class="text-green-500 text-sm">
                    <%= video.frame_count %> frames
                  </span>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Process Sample Video Button -->
          <div class="mt-4 pt-4 border-t border-gray-700">
            <button
              phx-click="process_video"
              phx-value-video_path="vid/The Obscure World of Model Train Synthesizers [wfu6wGAp83o].mp4"
              class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded font-semibold"
            >
              Process Sample Video
            </button>
          </div>
        </div>

        <!-- Search Form -->
        <div class="mb-8">
          <.form for={%{}} as={:search} phx-submit="search" class="max-w-2xl mx-auto">
            <div class="flex gap-4">
              <input
                type="text"
                name="search[term]"
                value={@search_term}
                placeholder="Search for text in video captions (e.g., 'choo choo')"
                class="flex-1 bg-gray-800 border border-green-600 text-green-400 px-4 py-3 rounded focus:outline-none focus:border-green-400"
              />
              <button
                type="submit"
                disabled={@loading}
                class="bg-green-600 hover:bg-green-700 disabled:bg-gray-600 text-white px-6 py-3 rounded font-semibold"
              >
                <%= if @loading, do: "SEARCHING...", else: "SEARCH" %>
              </button>
            </div>
          </.form>
        </div>

        <!-- Search Results -->
        <%= if @search_term != "" do %>
          <div class="mb-8">
            <h2 class="text-2xl font-semibold text-green-300 mb-4">
              Search Results for "<%= @search_term %>"
            </h2>
            
            <%= if @loading do %>
              <div class="text-center py-8">
                <div class="text-green-500">Searching through video frames...</div>
              </div>
            <% else %>
              <%= if length(@search_results) > 0 do %>
                <div class="text-green-500 mb-4">
                  Found <%= length(@search_results) %> matching frames
                </div>
                
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  <%= for frame <- @search_results do %>
                    <div class="bg-gray-800 border border-green-600 rounded p-4">
                      <div class="mb-2">
                        <%= if File.exists?(frame.file_path) do %>
                          <img
                            src={String.replace(frame.file_path, "priv/static", "")}
                            alt={"Frame at " <> format_timestamp(frame.timestamp_ms)}
                            class="w-full h-48 object-cover rounded border border-gray-600"
                          />
                        <% else %>
                          <div class="w-full h-48 bg-gray-700 flex items-center justify-center rounded border border-gray-600">
                            <span class="text-gray-500">Frame not found</span>
                          </div>
                        <% end %>
                      </div>
                      
                      <div class="text-sm">
                        <div class="text-green-400 font-semibold">
                          Frame #<%= frame.frame_number %>
                        </div>
                        <div class="text-green-500">
                          Time: <%= format_timestamp(frame.timestamp_ms) %>
                        </div>
                        <%= if frame.file_size do %>
                          <div class="text-green-600">
                            Size: <%= format_file_size(frame.file_size) %>
                          </div>
                        <% end %>
                        
                        <%= if Map.get(frame, :caption_texts) do %>
                          <div class="text-gray-300 text-sm bg-gray-900 p-2 rounded border border-gray-600 mt-2">
                            <strong class="text-green-400">Caption:</strong><br/>
                            "<%= frame.caption_texts %>"
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-center py-8">
                  <div class="text-green-500">No frames found matching "<%= @search_term %>"</div>
                  <div class="text-green-600 text-sm mt-2">
                    Try searching for terms like "train", "choo", or "sound"
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>

        <!-- Instructions -->
        <div class="bg-gray-800 border border-green-600 rounded p-6">
          <h3 class="text-lg font-semibold text-green-300 mb-3">How to Use</h3>
          <ol class="list-decimal list-inside space-y-2 text-green-500">
            <li>First, process a video using the "Process Sample Video" button above</li>
            <li>Wait for the video status to change to "COMPLETED" (this may take a few minutes)</li>
            <li>Enter search terms in the search box to find frames with matching captions</li>
            <li>View the extracted frames that match your search query</li>
          </ol>
          
          <div class="mt-4 pt-4 border-t border-gray-700">
            <h4 class="font-semibold text-green-300 mb-2">Example searches:</h4>
            <ul class="list-disc list-inside space-y-1 text-green-600 text-sm">
              <li>"train" - Find frames mentioning trains</li>
              <li>"choo choo" - Find frames with train sounds</li>
              <li>"sound" - Find frames discussing audio</li>
              <li>"synthesizer" - Find frames about synthesizers</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp status_class("pending"), do: "bg-yellow-600 text-yellow-100"
  defp status_class("processing"), do: "bg-blue-600 text-blue-100"
  defp status_class("completed"), do: "bg-green-600 text-green-100"
  defp status_class("failed"), do: "bg-red-600 text-red-100"
  defp status_class(_), do: "bg-gray-600 text-gray-100"

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