defmodule NathanForUsWeb.PublicTimelineLive do
  @moduledoc """
  Public timeline showing only Nathan GIFs posted by authenticated users.

  This is the social hub where people can only communicate in Nathan GIFs.
  Only cached GIFs from the database can be posted here, ensuring all content
  comes from the video timeline interface.
  """

  use NathanForUsWeb, :live_view

  alias NathanForUs.Viral
  alias NathanForUs.Accounts.User

  on_mount {NathanForUsWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    # Load 25 most recent GIFs with all associations for GIF display
    recent_gifs = Viral.get_recent_gifs(25)

    socket =
      socket
      |> assign(:page_title, "Nathan Timeline")
      |> assign(:gifs, recent_gifs)
      |> assign(:show_post_modal, false)
      |> assign(:loading, false)

    {:ok, socket}
  end

  def handle_event("show_post_modal", _params, socket) do
    if socket.assigns.current_user do
      socket = assign(socket, :show_post_modal, true)
      {:noreply, socket}
    else
      socket = put_flash(socket, :error, "Please sign up to post Nathan GIFs")
      {:noreply, socket}
    end
  end

  def handle_event("close_post_modal", _params, socket) do
    socket = assign(socket, :show_post_modal, false)
    {:noreply, socket}
  end

  def handle_event("random_gif", _params, socket) do
    case NathanForUs.Video.get_random_video_sequence(15) do
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

  def handle_event("view_gif", %{"gif_id" => gif_id}, socket) do
    # Record view interaction
    Viral.record_interaction(gif_id, "view",
      user_id: get_user_id(socket),
      session_id: get_connect_info(socket, :session)["live_socket_id"]
    )

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <!-- Simple Header -->
      <div class="bg-gray-800 border-b border-gray-700 px-6 py-4">
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <h1 class="text-2xl font-bold font-mono">Nathan Timeline</h1>

          <!-- Mobile: Stack buttons vertically, Desktop: Horizontal -->
          <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-2 sm:gap-4 w-full sm:w-auto">
            <.link
              navigate={~p"/video-timeline"}
              class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors text-center"
            >
              SEARCH QUOTES
            </.link>

            <.link
              navigate={~p"/browse-gifs"}
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors text-center"
            >
              BROWSE GIFS
            </.link>

            <button
              phx-click="random_gif"
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors text-center"
              title="Generate random GIF from any video"
            >
              🎲 Random GIF
            </button>

            <%= if @current_user do %>
              <button
                phx-click="show_post_modal"
                class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors text-center"
              >
                Post GIF
              </button>
            <% else %>
              <.link
                navigate={~p"/video-timeline"}
                class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors text-center"
              >
                MAKE A GIF
              </.link>
              <.link
                navigate={~p"/users/register"}
                class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors text-center"
              >
                Sign Up
              </.link>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Pure GIF Timeline -->
      <div class="px-4 py-6">
        <%= if Enum.empty?(@gifs) do %>
          <div class="text-center py-12">
            <div class="text-gray-400 font-mono mb-4">No Nathan GIFs yet</div>
            <%= if @current_user do %>
              <.link
                navigate={~p"/video-timeline"}
                class="text-blue-400 hover:text-blue-300 font-mono"
              >
                Create the first GIF →
              </.link>
            <% else %>
              <div class="space-y-3">
                <.link
                  navigate={~p"/video-timeline"}
                  class="text-green-400 hover:text-green-300 font-mono font-bold text-lg block"
                >
                  Make a GIF (no signup required) →
                </.link>
                <.link
                  navigate={~p"/users/register"}
                  class="text-blue-400 hover:text-blue-300 font-mono text-sm block"
                >
                  Or sign up to post GIFs to timeline →
                </.link>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- GIF Mosaic: 1 column on mobile, 3 columns on desktop -->
          <div class="max-w-6xl mx-auto">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <%= for gif <- @gifs, gif.gif && gif.gif.gif_data do %>
                <div
                  class="bg-gray-800 rounded-lg overflow-hidden border border-gray-700 hover:border-gray-600 transition-colors cursor-pointer"
                  phx-click="view_gif"
                  phx-value-gif_id={gif.id}
                >
                  <!-- Just the GIF - no metadata -->
                  <div class="aspect-video bg-gray-700">
                    <img
                      src={"data:image/gif;base64,#{NathanForUs.Gif.to_base64(gif.gif)}"}
                      alt="Nathan GIF"
                      class="w-full h-full object-cover"
                    />
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Call-to-Action for Signed Out Users -->
          <%= unless @current_user do %>
            <div class="mt-12 max-w-xl mx-auto">
              <div class="bg-gradient-to-r from-green-900/20 to-blue-900/20 border border-green-600/30 rounded-lg p-6 text-center">
                <h3 class="text-xl font-bold font-mono text-green-400 mb-3">
                  Ready to Create Your Own Nathan GIFs?
                </h3>
                <p class="text-gray-300 font-mono text-sm mb-6">
                  Join the conversation! Create hilarious Nathan moments and share them with the world.
                  No signup required to start making GIFs.
                </p>
                <div class="flex items-center justify-center gap-4">
                  <.link
                    navigate={~p"/video-timeline"}
                    class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-lg font-mono font-bold transition-colors shadow-lg"
                  >
                    🎬 START MAKING GIFS
                  </.link>
                  <.link
                    navigate={~p"/users/register"}
                    class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-mono font-medium transition-colors"
                  >
                    Sign Up to Post
                  </.link>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
      
    <!-- Post Modal -->
      <%= if @show_post_modal and @current_user do %>
        <div class="fixed inset-0 bg-black bg-opacity-80 flex items-center justify-center z-50">
          <div class="bg-gray-800 rounded-lg shadow-xl max-w-lg w-full mx-4 border border-gray-600">
            <div class="p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-bold font-mono">Post Nathan GIF</h2>
                <button
                  phx-click="close_post_modal"
                  class="text-gray-400 hover:text-white transition-colors"
                >
                  ✕
                </button>
              </div>

              <div class="text-center py-8">
                <div class="text-gray-400 font-mono mb-4">
                  Create a GIF first!
                </div>
                <p class="text-gray-500 text-sm mb-6">
                  GIFs can only be posted from the video timeline.
                </p>

                <.link
                  navigate={~p"/video-timeline"}
                  class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-mono font-medium transition-colors inline-block"
                >
                  Go Create GIF →
                </.link>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp get_user_id(socket) do
    case socket.assigns[:current_user] do
      %User{id: id} -> id
      _ -> nil
    end
  end
end
