defmodule NathanForUsWeb.GifBrowseLive do
  @moduledoc """
  Browse page showing ALL generated GIFs for inspiration.

  Users can browse GIFs others have made (but not necessarily posted)
  and repost them to the public timeline if they want.
  """

  use NathanForUsWeb, :live_view

  alias NathanForUs.Viral

  on_mount {NathanForUsWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    # Load 50 most recent browseable GIFs
    browseable_gifs = Viral.get_recent_browseable_gifs(50)

    socket =
      socket
      |> assign(:page_title, "Browse Nathan GIFs")
      |> assign(:gifs, browseable_gifs)
      |> assign(:loading, false)

    {:ok, socket}
  end

  def handle_event("repost_gif", %{"gif_id" => browseable_gif_id}, socket) do
    if socket.assigns.current_user do
      # Find the browseable GIF
      browseable_gif = Enum.find(socket.assigns.gifs, &(&1.id == String.to_integer(browseable_gif_id)))

      if browseable_gif do
        # Create a viral GIF post from this browseable GIF
        attrs = %{
          video_id: browseable_gif.video_id,
          created_by_user_id: socket.assigns.current_user.id,
          gif_id: browseable_gif.gif_id, # Link to actual GIF binary
          start_frame_index: browseable_gif.start_frame_index,
          end_frame_index: browseable_gif.end_frame_index,
          category: browseable_gif.category,
          frame_data: browseable_gif.frame_data,
          title: browseable_gif.title
        }

        case Viral.create_viral_gif(attrs) do
          {:ok, _viral_gif} ->
            socket = put_flash(socket, :info, "GIF posted to public timeline!")
            {:noreply, socket}

          {:error, _reason} ->
            socket = put_flash(socket, :error, "Failed to post GIF to timeline")
            {:noreply, socket}
        end
      else
        socket = put_flash(socket, :error, "GIF not found")
        {:noreply, socket}
      end
    else
      socket = put_flash(socket, :error, "Please log in to post GIFs")
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
            <h1 class="text-2xl font-bold font-mono">Browse Nathan GIFs</h1>
            <p class="text-gray-400 text-sm font-mono">
              All GIFs created by users • Find inspiration to repost
            </p>
          </div>

          <div class="flex items-center gap-4">
            <.link
              navigate={~p"/public-timeline"}
              class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
            >
              Public Timeline
            </.link>
            <.link
              navigate={~p"/video-timeline"}
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
            >
              Create GIF
            </.link>
          </div>
        </div>
      </div>

      <!-- GIF Grid -->
      <div class="px-4 py-6">
        <%= if Enum.empty?(@gifs) do %>
          <div class="text-center py-12">
            <div class="text-gray-400 font-mono mb-4">No GIFs created yet</div>
            <.link navigate={~p"/video-timeline"} class="text-blue-400 hover:text-blue-300 font-mono">
              Create the first GIF →
            </.link>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 max-w-7xl mx-auto">
            <%= for gif <- @gifs do %>
              <div class="bg-gray-800 rounded-lg overflow-hidden border border-gray-700 hover:border-gray-600 transition-colors">
                <!-- GIF Display -->
                <div class="aspect-video bg-gray-700 flex items-center justify-center">
                  <%= if gif.gif && gif.gif.gif_data do %>
                    <img
                      src={"data:image/gif;base64,#{NathanForUs.Gif.to_base64(gif.gif)}"}
                      alt={gif.title || "Nathan GIF"}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="text-gray-400 font-mono text-sm text-center p-4">
                      <div>Nathan GIF</div>
                      <div class="text-xs mt-1">Frames <%= gif.start_frame_index %>-<%= gif.end_frame_index %></div>
                    </div>
                  <% end %>
                </div>

                <!-- GIF Info & Actions -->
                <div class="p-4">
                  <h3 class="text-white font-mono text-sm mb-2 truncate">
                    <%= gif.title || "Untitled Nathan GIF" %>
                  </h3>

                  <div class="text-gray-400 text-xs font-mono mb-3">
                    From: <%= gif.video.title %>
                  </div>

                  <div class="flex items-center justify-between">
                    <div class="text-gray-500 text-xs font-mono">
                      <%= format_time_ago(gif.inserted_at) %>
                    </div>

                    <%= if @current_user do %>
                      <button
                        phx-click="repost_gif"
                        phx-value-gif_id={gif.id}
                        class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded text-xs font-mono transition-colors"
                      >
                        Repost
                      </button>
                    <% else %>
                      <.link
                        navigate={~p"/users/register"}
                        class="bg-gray-600 hover:bg-gray-500 text-white px-3 py-1 rounded text-xs font-mono transition-colors"
                      >
                        Sign Up
                      </.link>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 2592000 -> "#{div(diff, 86400)}d ago"
      true -> "#{div(diff, 2592000)}mo ago"
    end
  end
end
