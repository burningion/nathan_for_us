defmodule NathanForUsWeb.AdminLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.AdminService

  on_mount {NathanForUsWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    case AdminService.validate_admin_access(socket.assigns.current_user) do
      :ok ->
        stats = AdminService.get_admin_stats()
        
        {:ok, assign(socket,
          stats: stats,
          backfill_running: false,
          backfill_results: nil,
          page_title: "Admin Dashboard",
          page_description: "Administrative functions for Nathan For Us"
        )}
      
      {:error, :access_denied} ->
        {:ok, 
          socket
          |> put_flash(:error, "Access denied. Admin privileges required.")
          |> redirect(to: ~p"/")}
    end
  end

  def handle_event("start_backfill", %{"limit" => limit_str, "dry_run" => dry_run_str}, socket) do
    if not AdminService.can_start_backfill?(socket.assigns.backfill_running) do
      {:noreply, put_flash(socket, :error, "Backfill already running")}
    else
      params = %{"limit" => limit_str, "dry_run" => dry_run_str}
      
      case AdminService.parse_backfill_params(params) do
        {:ok, options} ->
          case AdminService.start_backfill(options) do
            {:ok, task} ->
              {:noreply, 
                socket
                |> assign(
                  backfill_running: true,
                  backfill_task: task,
                  backfill_results: nil
                )
                |> put_flash(:info, "Starting profile backfill...")}
            
            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Failed to start backfill: #{reason}")}
          end
        
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  def handle_event("refresh_stats", _params, socket) do
    stats = AdminService.get_admin_stats()
    {:noreply, assign(socket, stats: stats)}
  end

  def handle_info({ref, result}, socket) do
    if socket.assigns[:backfill_task] && socket.assigns.backfill_task.ref == ref do
      Process.demonitor(ref, [:flush])
      
      case AdminService.handle_backfill_completion(result) do
        {:ok, results} ->
          stats = AdminService.get_admin_stats()
          
          {:noreply,
            socket
            |> assign(
              backfill_running: false,
              backfill_results: results,
              stats: stats,
              backfill_task: nil
            )
            |> put_flash(:info, "Backfill completed successfully")}
        
        {:error, reason} ->
          {:noreply,
            socket
            |> assign(
              backfill_running: false,
              backfill_task: nil
            )
            |> put_flash(:error, reason)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    if socket.assigns[:backfill_task] && socket.assigns.backfill_task.ref == ref do
      # Task crashed
      {:noreply,
        socket
        |> assign(
          backfill_running: false,
          backfill_task: nil
        )
        |> put_flash(:error, "Backfill task crashed: #{inspect(reason)}")}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 p-6">
      <div class="max-w-6xl mx-auto">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-zinc-900 mb-2">Admin Dashboard</h1>
          <p class="text-zinc-600">Administrative functions for Nathan For Us</p>
        </div>

        <!-- Stats Section -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">Total Posts</p>
                <p class="text-2xl font-bold text-zinc-900"><%= @stats.total_posts %></p>
              </div>
              <div class="h-8 w-8 bg-blue-500 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                </svg>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">Posts with Profiles</p>
                <p class="text-2xl font-bold text-green-600"><%= @stats.posts_with_users %></p>
              </div>
              <div class="h-8 w-8 bg-green-500 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.121 17.804A13.937 13.937 0 0112 16c2.5 0 4.847.655 6.879 1.804M15 10a3 3 0 11-6 0 3 3 0 016 0zm6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-zinc-600">Posts Missing Profiles</p>
                <p class="text-2xl font-bold text-red-600"><%= @stats.posts_without_users %></p>
              </div>
              <div class="h-8 w-8 bg-red-500 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
                </svg>
              </div>
            </div>
          </div>
        </div>

        <!-- Backfill Section -->
        <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200 mb-8">
          <h2 class="text-xl font-bold text-zinc-900 mb-4">Profile Backfill</h2>
          <p class="text-zinc-600 mb-6">
            Fetch Bluesky user profiles for posts that don't have associated user data. This will improve the display of posts with proper avatars and user information.
          </p>

          <form phx-submit="start_backfill" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label for="limit" class="block text-sm font-medium text-zinc-700 mb-2">
                  Number of posts to process
                </label>
                <select name="limit" id="limit" class="block w-full rounded-md border-zinc-300 shadow-sm focus:border-blue-500 focus:ring-blue-500">
                  <option value="10">10 posts</option>
                  <option value="25">25 posts</option>
                  <option value="50" selected>50 posts</option>
                  <option value="100">100 posts</option>
                  <option value="200">200 posts</option>
                </select>
              </div>

              <div>
                <label for="dry_run" class="block text-sm font-medium text-zinc-700 mb-2">
                  Mode
                </label>
                <select name="dry_run" id="dry_run" class="block w-full rounded-md border-zinc-300 shadow-sm focus:border-blue-500 focus:ring-blue-500">
                  <option value="true">Dry run (preview only)</option>
                  <option value="false">Live run (make changes)</option>
                </select>
              </div>
            </div>

            <div class="flex items-center space-x-4">
              <button 
                type="submit" 
                disabled={@backfill_running}
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <%= if @backfill_running do %>
                  <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Running...
                <% else %>
                  Start Backfill
                <% end %>
              </button>

              <button 
                type="button" 
                phx-click="refresh_stats"
                class="inline-flex items-center px-4 py-2 border border-zinc-300 text-sm font-medium rounded-md text-zinc-700 bg-white hover:bg-zinc-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Refresh Stats
              </button>
            </div>
          </form>

          <!-- Results -->
          <%= if @backfill_results do %>
            <div class="mt-6 p-4 bg-zinc-50 rounded-md">
              <h3 class="text-lg font-medium text-zinc-900 mb-2">
                <%= if @backfill_results.dry_run, do: "Dry Run Results", else: "Backfill Results" %>
              </h3>
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                <div>
                  <span class="font-medium text-zinc-600">Posts Found:</span>
                  <span class="ml-2"><%= @backfill_results.posts_found %></span>
                </div>
                <div>
                  <span class="font-medium text-zinc-600">Unique DIDs:</span>
                  <span class="ml-2"><%= @backfill_results.unique_dids %></span>
                </div>
                <div>
                  <span class="font-medium text-zinc-600">Successful:</span>
                  <span class="ml-2 text-green-600"><%= @backfill_results.successful %></span>
                </div>
                <div>
                  <span class="font-medium text-zinc-600">Failed:</span>
                  <span class="ml-2 text-red-600"><%= @backfill_results.failed %></span>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Additional Stats -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
            <h3 class="text-lg font-medium text-zinc-900 mb-4">User Statistics</h3>
            <div class="space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-zinc-600">Total Bluesky Users:</span>
                <span class="font-medium"><%= @stats.total_users %></span>
              </div>
              <div class="flex justify-between">
                <span class="text-zinc-600">Unique DIDs in Posts:</span>
                <span class="font-medium"><%= @stats.unique_dids_in_posts %></span>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg p-6 shadow-sm border border-zinc-200">
            <h3 class="text-lg font-medium text-zinc-900 mb-4">Coverage</h3>
            <div class="space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-zinc-600">Profile Coverage:</span>
                <span class="font-medium">
                  <%= if @stats.total_posts > 0 do %>
                    <%= Float.round(@stats.posts_with_users / @stats.total_posts * 100, 1) %>%
                  <% else %>
                    0%
                  <% end %>
                </span>
              </div>
              <div class="w-full bg-zinc-200 rounded-full h-2">
                <div 
                  class="bg-green-600 h-2 rounded-full" 
                  style={"width: #{if @stats.total_posts > 0, do: @stats.posts_with_users / @stats.total_posts * 100, else: 0}%"}
                ></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end