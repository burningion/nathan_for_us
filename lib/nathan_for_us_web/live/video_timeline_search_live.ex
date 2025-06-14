defmodule NathanForUsWeb.VideoTimelineSearchLive do
  @moduledoc """
  Primary entrypoint for GIF creation.

  Provides a search interface with random quote suggestions and displays
  results grouped by episode with frame previews.
  """

  use NathanForUsWeb, :live_view

  import Ecto.Query
  alias NathanForUs.{Video, Repo}
  alias NathanForUs.Video.Video, as: VideoModel

  def mount(_params, _session, socket) do
    # Get random quote suggestions for initial display
    random_quotes = Video.get_sample_caption_suggestions(18)
    
    # Get all videos for the video list
    all_videos = Video.list_videos() |> Enum.sort_by(& &1.title)

    socket =
      socket
      |> assign(:page_title, "Timeline Search")
      |> assign(:search_term, "")
      |> assign(:search_form, to_form(%{}))
      |> assign(:random_quotes, random_quotes)
      |> assign(:all_videos, all_videos)
      |> assign(:search_results, [])
      |> assign(:loading, false)
      |> assign(:has_searched, false)

    {:ok, socket}
  end

  def handle_event("search", %{"search" => %{"term" => term}}, socket) do
    term = String.trim(term)

    if String.length(term) >= 3 do
      socket = assign(socket, :loading, true)

      # Search for frames across all videos
      search_results = Video.search_frames_by_text_simple(term)

      # Group results by video and add video information
      grouped_results = group_results_by_video(search_results)

      socket =
        socket
        |> assign(:search_term, term)
        |> assign(:search_results, grouped_results)
        |> assign(:loading, false)
        |> assign(:has_searched, true)

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:search_results, [])
        |> assign(:has_searched, false)
        |> assign(:loading, false)

      {:noreply, socket}
    end
  end

  def handle_event("select_quote", %{"quote" => quote}, socket) do
    # Fill the search input with the selected quote and trigger search
    socket = assign(socket, :search_term, quote)

    # Trigger the search automatically
    send(self(), {:auto_search, quote})

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:has_searched, false)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  def handle_event("random_gif", _params, socket) do
    case Video.get_random_video_sequence(15) do
      {:ok, video_id, start_frame} ->
        # Generate a range of 15 frame indices starting from the random frame
        frame_indices = Enum.to_list(0..14)
        indices_param = Enum.join(frame_indices, ",")

        # Navigate to the video timeline with pre-selected frames
        path =
          ~p"/video-timeline/#{video_id}?random=true&start_frame=#{start_frame}&selected_indices=#{indices_param}"

        socket = redirect(socket, to: path)
        {:noreply, socket}

      {:error, _reason} ->
        socket = put_flash(socket, :error, "No suitable videos found for random GIF generation")
        {:noreply, socket}
    end
  end

  def handle_info({:auto_search, term}, socket) do
    if String.length(term) >= 3 do
      socket = assign(socket, :loading, true)

      search_results = Video.search_frames_by_text_simple(term)
      grouped_results = group_results_by_video(search_results)

      socket =
        socket
        |> assign(:search_results, grouped_results)
        |> assign(:loading, false)
        |> assign(:has_searched, true)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <!-- Header -->
      <div class="bg-gray-800 border-b border-gray-700 px-6 py-4">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold font-mono">Timeline Search</h1>
            <p class="text-gray-400 text-sm font-mono">
              Search for quotes to create GIFs • Primary GIF creation entrypoint
            </p>
          </div>

          <div class="flex items-center gap-4">
            <button
              phx-click="random_gif"
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
              title="Generate random GIF from any video"
            >
              🎲 Random GIF
            </button>

            <.link
              navigate={~p"/browse-gifs"}
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
            >
              Browse GIFs
            </.link>
            <.link
              navigate={~p"/public-timeline"}
              class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
            >
              NATHAN POST TIMELINE
            </.link>
            <.link
              navigate={~p"/users/register"}
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
            >
              Sign Up
            </.link>
          </div>
        </div>
      </div>
      
    <!-- Search Section -->
      <div class="px-6 py-6">
        <div class="max-w-4xl mx-auto">
          <.form for={@search_form} phx-submit="search" class="mb-8">
            <div class="flex gap-4">
              <input
                type="text"
                name="search[term]"
                value={@search_term}
                placeholder="Search for quotes to create GIFs..."
                class="flex-1 bg-gray-800 border border-gray-600 rounded-lg px-4 py-3 text-white placeholder-gray-400 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 font-mono"
                phx-debounce="300"
              />
              <button
                type="submit"
                class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-mono font-medium transition-colors"
                disabled={@loading}
              >
                <%= if @loading do %>
                  Searching...
                <% else %>
                  Search
                <% end %>
              </button>
              <button
                type="button"
                phx-click="random_gif"
                class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-mono font-medium transition-colors"
              >
                🎲 Random
              </button>
              <%= if @has_searched do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-3 rounded-lg font-mono transition-colors"
                >
                  Clear
                </button>
              <% end %>
            </div>
          </.form>
          
    <!-- Random Quote Suggestions (show when no search) -->
          <%= unless @has_searched do %>
            <div class="mb-8">
              <h2 class="text-lg font-bold font-mono text-blue-400 mb-4">
                Try searching for these quotes:
              </h2>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                <%= for quote <- @random_quotes do %>
                  <button
                    phx-click="select_quote"
                    phx-value-quote={quote}
                    class="bg-gray-800 hover:bg-gray-700 border border-gray-600 rounded-lg p-4 text-left transition-all hover:border-blue-500 group"
                  >
                    <p class="text-gray-200 text-sm leading-relaxed group-hover:text-white font-mono">
                      "{quote}"
                    </p>
                  </button>
                <% end %>
              </div>
            </div>
            
            <!-- Video List -->
            <div class="mt-8">
              <h2 class="text-lg font-bold font-mono text-green-400 mb-4">
                Browse by Episode:
              </h2>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for video <- @all_videos do %>
                  <.link
                    navigate={~p"/video-timeline/#{video.id}"}
                    class="bg-gray-800 hover:bg-gray-700 border border-gray-600 hover:border-green-500 rounded-lg p-4 transition-all group"
                  >
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <h3 class="text-white font-mono font-medium group-hover:text-green-400 transition-colors">
                          <%= video.title %>
                        </h3>
                        <div class="flex items-center gap-4 mt-2 text-xs text-gray-400 font-mono">
                          <%= if video.frame_count do %>
                            <span>📸 <%= video.frame_count %> frames</span>
                          <% end %>
                          <%= if video.duration_ms do %>
                            <span>⏱️ <%= format_duration(video.duration_ms) %></span>
                          <% end %>
                          <span class={"inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{status_badge_class(video.status)}"}>
                            <%= video.status %>
                          </span>
                        </div>
                      </div>
                      <div class="text-gray-400 group-hover:text-green-400 transition-colors">
                        →
                      </div>
                    </div>
                  </.link>
                <% end %>
              </div>
            </div>
          <% end %>
          
    <!-- Search Results -->
          <%= if @loading do %>
            <div class="text-center py-12">
              <div class="text-gray-400 font-mono">Searching for quotes...</div>
            </div>
          <% end %>

          <%= if @has_searched and not @loading do %>
            <%= if Enum.empty?(@search_results) do %>
              <div class="text-center py-12">
                <div class="text-gray-400 font-mono mb-4">No quotes found for "{@search_term}"</div>
                <p class="text-gray-500 text-sm mb-6">
                  Try a different search term or browse the suggestions above.
                </p>
                
    <!-- Feeling Lucky Section -->
                <div class="bg-gray-800 border border-gray-600 rounded-lg p-6 max-w-md mx-auto">
                  <h3 class="text-lg font-bold font-mono text-yellow-400 mb-3">🎲 Feeling Lucky?</h3>
                  <p class="text-gray-300 text-sm mb-4 font-mono">
                    Can't find what you're looking for? Let us surprise you with a random Nathan moment!
                  </p>
                  <button
                    phx-click="random_gif"
                    class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-mono font-bold transition-colors shadow-lg text-lg"
                  >
                    🎲 Generate Random GIF
                  </button>
                </div>
              </div>
            <% else %>
              <div class="space-y-8">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-bold font-mono text-blue-400">
                    Found {total_frame_count(@search_results)} frames across {length(@search_results)} episodes
                  </h2>
                </div>
                
    <!-- Results grouped by video/episode -->
                <%= for {video, frames} <- @search_results do %>
                  <div class="bg-gray-800 border border-gray-700 rounded-lg p-6">
                    <div class="flex items-center justify-between mb-4">
                      <div>
                        <h3 class="text-xl font-bold font-mono text-white">{video.title}</h3>
                        <p class="text-gray-400 text-sm font-mono">
                          {length(frames)} matching frames
                        </p>
                      </div>
                      <.link
                        navigate={build_timeline_link(video.id, frames, @search_term)}
                        class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
                      >
                        Create GIF →
                      </.link>
                    </div>
                    
    <!-- Frame previews -->
                    <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
                      <%= for frame <- Enum.take(frames, 12) do %>
                        <div class="group">
                          <%= if frame.image_data do %>
                            <div
                              class="relative cursor-pointer"
                              onclick={"window.location.href = '#{build_frame_context_link(video.id, frame, @search_term)}'"}
                            >
                              <img
                                src={"data:image/jpeg;base64,#{encode_frame_image(frame.image_data)}"}
                                alt={"Frame ##{frame.frame_number}"}
                                class="w-full aspect-video object-cover rounded-lg border border-gray-600 group-hover:border-blue-500 transition-colors hover:scale-105 transform transition-transform duration-200"
                              />
                              <div class="absolute bottom-1 right-1 bg-black bg-opacity-75 text-white text-xs px-1 py-0.5 rounded font-mono">
                                #{frame.frame_number}
                              </div>
                              <div class="absolute inset-0 bg-blue-500 bg-opacity-0 group-hover:bg-opacity-20 transition-all duration-200 rounded-lg flex items-center justify-center">
                                <div class="opacity-0 group-hover:opacity-100 transition-opacity duration-200 bg-black bg-opacity-75 text-white px-2 py-1 rounded text-xs font-mono">
                                  Click to compose GIF
                                </div>
                              </div>
                            </div>
                          <% else %>
                            <div class="w-full aspect-video bg-gray-700 rounded-lg border border-gray-600 flex items-center justify-center">
                              <span class="text-gray-400 text-xs font-mono">No image</span>
                            </div>
                          <% end %>
                          
    <!-- Quote preview -->
                          <%= if frame.caption_texts do %>
                            <div class="mt-2 p-2 bg-gray-700 rounded text-xs leading-tight">
                              <p class="text-gray-300 font-mono line-clamp-2">
                                "{String.slice(frame.caption_texts, 0, 100)}{if String.length(
                                                                                  frame.caption_texts
                                                                                ) > 100,
                                                                                do: "..."}"
                              </p>
                            </div>
                          <% end %>
                        </div>
                      <% end %>

                      <%= if length(frames) > 12 do %>
                        <div class="col-span-full text-center mt-4">
                          <span class="text-gray-400 font-mono text-sm">
                            + {length(frames) - 12} more frames
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp group_results_by_video(search_results) do
    # Get unique video IDs from results
    video_ids = search_results |> Enum.map(& &1.video_id) |> Enum.uniq()

    # Get video information
    videos =
      VideoModel
      |> where([v], v.id in ^video_ids)
      |> Repo.all()
      |> Enum.into(%{}, fn video -> {video.id, video} end)

    # Group frames by video
    search_results
    |> Enum.group_by(& &1.video_id)
    |> Enum.map(fn {video_id, frames} ->
      video = Map.get(videos, video_id)
      {video, frames}
    end)
    |> Enum.reject(fn {video, _frames} -> is_nil(video) end)
    |> Enum.sort_by(fn {video, _frames} -> video.title end)
  end

  defp total_frame_count(grouped_results) do
    grouped_results
    |> Enum.map(fn {_video, frames} -> length(frames) end)
    |> Enum.sum()
  end

  defp build_timeline_link(video_id, _frames, search_term) do
    encoded_search_term = URI.encode(search_term)
    ~p"/video-timeline/#{video_id}?search=#{encoded_search_term}"
  end

  defp build_frame_context_link(video_id, frame, search_term) do
    encoded_search_term = URI.encode(search_term)

    ~p"/video-timeline/#{video_id}?search=#{encoded_search_term}&context_frame=#{frame.frame_number}"
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

  defp format_duration(duration_ms) when is_integer(duration_ms) do
    total_seconds = div(duration_ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end

  defp format_duration(_), do: "Unknown"

  defp status_badge_class("completed"), do: "bg-green-100 text-green-800"
  defp status_badge_class("processing"), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_class("pending"), do: "bg-gray-100 text-gray-800"
  defp status_badge_class("failed"), do: "bg-red-100 text-red-800"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-800"
end
