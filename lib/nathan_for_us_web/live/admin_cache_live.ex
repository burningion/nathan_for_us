defmodule NathanForUsWeb.AdminCacheLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.{AdminService, FrameCache}
  alias NathanForUs.Viral

  on_mount {NathanForUsWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    case AdminService.validate_admin_access(socket.assigns.current_user) do
      :ok ->
        frame_stats = FrameCache.stats()
        
        # Get initial cache entries sample
        cache_entries = get_cache_entries_sample(20)
        
        # Get gif cache stats if available
        gif_stats = get_gif_cache_stats()

        {:ok,
         assign(socket,
           frame_stats: frame_stats,
           gif_stats: gif_stats,
           cache_entries: cache_entries,
           page_title: "Cache Admin",
           page_description: "Cache management and inspection",
           loading: false,
           entries_limit: 20
         )}

      {:error, :access_denied} ->
        {:ok,
         socket
         |> put_flash(:error, "Access denied. Admin privileges required.")
         |> redirect(to: ~p"/")}
    end
  end

  def handle_event("refresh_stats", _params, socket) do
    frame_stats = FrameCache.stats()
    gif_stats = get_gif_cache_stats()
    cache_entries = get_cache_entries_sample(socket.assigns.entries_limit)

    socket =
      socket
      |> assign(:frame_stats, frame_stats)
      |> assign(:gif_stats, gif_stats)
      |> assign(:cache_entries, cache_entries)
      |> put_flash(:info, "Cache statistics refreshed")

    {:noreply, socket}
  end

  def handle_event("clear_frame_cache", _params, socket) do
    case FrameCache.clear() do
      :ok ->
        frame_stats = FrameCache.stats()
        cache_entries = get_cache_entries_sample(socket.assigns.entries_limit)

        socket =
          socket
          |> assign(:frame_stats, frame_stats)
          |> assign(:cache_entries, cache_entries)
          |> put_flash(:info, "Frame cache cleared successfully")

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to clear cache: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_event("warm_cache", _params, socket) do
    FrameCache.warm_cache()
    
    socket = put_flash(socket, :info, "Cache warming started in background")
    {:noreply, socket}
  end

  def handle_event("load_more_entries", _params, socket) do
    new_limit = socket.assigns.entries_limit + 20
    cache_entries = get_cache_entries_sample(new_limit)

    socket =
      socket
      |> assign(:entries_limit, new_limit)
      |> assign(:cache_entries, cache_entries)

    {:noreply, socket}
  end

  def handle_event("evict_frame", %{"frame_id" => frame_id_str}, socket) do
    frame_id = String.to_integer(frame_id_str)
    FrameCache.evict(frame_id)

    # Refresh data
    frame_stats = FrameCache.stats()
    cache_entries = get_cache_entries_sample(socket.assigns.entries_limit)

    socket =
      socket
      |> assign(:frame_stats, frame_stats)
      |> assign(:cache_entries, cache_entries)
      |> put_flash(:info, "Frame #{frame_id} evicted from cache")

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 p-6">
      <div class="max-w-7xl mx-auto">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-zinc-900 mb-2">Cache Administration</h1>
          <p class="text-zinc-600">Monitor and manage system caches</p>
        </div>

        <!-- Admin Navigation -->
        <div class="mb-8">
          <nav class="flex space-x-4">
            <.link
              navigate={~p"/admin"}
              class="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
            >
              Dashboard
            </.link>
            <.link
              navigate={~p"/admin/upload"}
              class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
            >
              Upload Video
            </.link>
            <.link
              navigate={~p"/admin/frames"}
              class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
            >
              Browse Frames
            </.link>
            <.link
              navigate={~p"/admin/cache"}
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Cache Admin
            </.link>
          </nav>
        </div>

        <!-- Frame Cache Stats -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">Cached Frames</p>
                <p class="text-2xl font-bold text-blue-600"><%= @frame_stats.cached_frames %></p>
                <p class="text-xs text-zinc-500">max: <%= @frame_stats.max_capacity %></p>
              </div>
              <div class="h-8 w-8 bg-blue-500 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                </svg>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">Memory Usage</p>
                <p class="text-2xl font-bold text-green-600"><%= @frame_stats.memory_usage_mb %> MB</p>
                <p class="text-xs text-zinc-500"><%= @frame_stats.memory_usage_percent %>% of <%= @frame_stats.max_memory_mb %>MB</p>
              </div>
              <div class="h-8 w-8 bg-green-500 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
                </svg>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">Popular Frames</p>
                <p class="text-2xl font-bold text-orange-600"><%= @frame_stats.popular_frames %></p>
                <p class="text-xs text-zinc-500">accessed 3+ times</p>
              </div>
              <div class="h-8 w-8 bg-orange-500 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"></path>
                </svg>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">GIF Usage</p>
                <p class="text-2xl font-bold text-purple-600"><%= @frame_stats.frames_used_in_gifs %></p>
                <p class="text-xs text-zinc-500">avg: <%= @frame_stats.avg_accesses %></p>
              </div>
              <div class="h-8 w-8 bg-purple-500 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h4a1 1 0 011 1v2m3 0V2a1 1 0 011-1h4a1 1 0 011 1v2m-6 9l2 2 4-4"></path>
                </svg>
              </div>
            </div>
          </div>
        </div>

        <!-- Cache Controls -->
        <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200 mb-8">
          <h2 class="text-xl font-bold text-zinc-900 mb-4">Cache Management</h2>
          <div class="flex flex-wrap gap-4">
            <button
              phx-click="refresh_stats"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
              </svg>
              Refresh Stats
            </button>

            <button
              phx-click="warm_cache"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
              </svg>
              Warm Cache
            </button>

            <button
              phx-click="clear_frame_cache"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
              data-confirm="Are you sure you want to clear the entire frame cache?"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
              </svg>
              Clear Cache
            </button>
          </div>
        </div>

        <!-- GIF Cache Stats (if available) -->
        <%= if @gif_stats do %>
          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200 mb-8">
            <h2 class="text-xl font-bold text-zinc-900 mb-4">GIF Cache Statistics</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
              <div>
                <span class="font-medium text-zinc-600">Total GIFs:</span>
                <span class="ml-2"><%= @gif_stats.total_gifs %></span>
              </div>
              <div>
                <span class="font-medium text-zinc-600">Recent GIFs:</span>
                <span class="ml-2"><%= @gif_stats.recent_gifs %></span>
              </div>
              <div>
                <span class="font-medium text-zinc-600">Popular GIFs:</span>
                <span class="ml-2"><%= @gif_stats.popular_gifs %></span>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Cached Entries Browser -->
        <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-bold text-zinc-900">Cached Frame Entries</h2>
            <button
              phx-click="load_more_entries"
              class="text-sm text-blue-600 hover:text-blue-800"
            >
              Load More (showing <%= @entries_limit %>)
            </button>
          </div>

          <%= if Enum.empty?(@cache_entries) do %>
            <div class="text-center py-8 text-zinc-500">
              <p>No frames currently cached</p>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-zinc-200">
                <thead class="bg-zinc-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Frame ID</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Video</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Access Count</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Last Accessed</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">GIF Usage</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Size</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-zinc-200">
                  <%= for entry <- @cache_entries do %>
                    <tr class="hover:bg-zinc-50">
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-zinc-900">
                        <%= entry.frame_id %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">
                        <div>
                          <div class="font-medium text-zinc-900">Video <%= entry.video_id %></div>
                          <div class="text-xs text-zinc-500">Frame <%= entry.frame_number %></div>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={[
                          "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                          if(entry.access_count >= 3, 
                            do: "bg-green-100 text-green-800", 
                            else: "bg-zinc-100 text-zinc-800")
                        ]}>
                          <%= entry.access_count %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">
                        <%= time_ago(entry.last_accessed) %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">
                        <%= entry.gif_usage_count || 0 %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">
                        <%= format_bytes(entry.compressed_size) %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-zinc-500">
                        <button
                          phx-click="evict_frame"
                          phx-value-frame_id={entry.frame_id}
                          class="text-red-600 hover:text-red-800 text-xs"
                          data-confirm={"Evict frame #{entry.frame_id} from cache?"}
                        >
                          Evict
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp get_cache_entries_sample(limit) do
    # Get a sample of cache entries from ETS
    try do
      :ets.foldl(fn {frame_id, {compressed_data, access_count, last_accessed, metadata}}, acc ->
        entry = %{
          frame_id: frame_id,
          access_count: access_count,
          last_accessed: last_accessed,
          gif_usage_count: Map.get(metadata, :gif_usage_count, 0),
          compressed_size: byte_size(compressed_data),
          video_id: Map.get(metadata, :video_id),
          frame_number: Map.get(metadata, :frame_number),
          timestamp_ms: Map.get(metadata, :timestamp_ms)
        }
        [entry | acc]
      end, [], :frame_cache)
      |> Enum.sort_by(& &1.access_count, :desc)
      |> Enum.take(limit)
    rescue
      _ -> []
    end
  end

  defp get_gif_cache_stats do
    # Get statistics about GIFs that might be cached
    try do
      total_gifs = Viral.get_recent_gifs(1000) |> length()
      recent_gifs = Viral.get_recent_gifs(50) |> length()
      popular_gifs = Viral.get_trending_gifs(25) |> length()

      %{
        total_gifs: total_gifs,
        recent_gifs: recent_gifs,
        popular_gifs: popular_gifs
      }
    rescue
      _ -> nil
    end
  end

  defp time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 2_592_000 -> "#{div(diff, 86400)}d ago"
      true -> "#{div(diff, 2_592_000)}mo ago"
    end
  end

  defp format_bytes(bytes) when bytes >= 1_048_576 do
    "#{Float.round(bytes / 1_048_576, 2)} MB"
  end

  defp format_bytes(bytes) when bytes >= 1024 do
    "#{Float.round(bytes / 1024, 1)} KB"
  end

  defp format_bytes(bytes) do
    "#{bytes} B"
  end
end