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

  def mount(_params, _session, socket) do
    # Load 25 most recent GIFs
    recent_gifs = Viral.get_recent_gifs(25)
    
    socket =
      socket
      |> assign(:page_title, "Nathan Timeline")
      |> assign(:gifs, recent_gifs)
      |> assign(:show_post_modal, false)
      |> assign(:loading, false)
      |> assign(:current_user, Map.get(socket.assigns, :current_user))

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
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold font-mono">Nathan Timeline</h1>
          
          <div class="flex items-center gap-4">
            <%= if @current_user do %>
              <button
                phx-click="show_post_modal"
                class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
              >
                Post GIF
              </button>
            <% else %>
              <.link
                navigate={~p"/users/register"}
                class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
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
              <.link navigate={~p"/video-timeline"} class="text-blue-400 hover:text-blue-300 font-mono">
                Create the first GIF →
              </.link>
            <% else %>
              <.link navigate={~p"/users/register"} class="text-blue-400 hover:text-blue-300 font-mono">
                Sign up to post GIFs →
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 max-w-6xl mx-auto">
            <%= for gif <- @gifs do %>
              <div 
                class="bg-gray-800 rounded-lg overflow-hidden border border-gray-700 hover:border-gray-600 transition-colors"
                phx-click="view_gif"
                phx-value-gif_id={gif.id}
              >
                <!-- Just the GIF - no metadata -->
                <div class="aspect-video bg-gray-700 flex items-center justify-center">
                  <div class="text-gray-400 font-mono text-sm">
                    Nathan GIF #<%= gif.id %>
                  </div>
                  <!-- TODO: Replace with actual GIF when we integrate with Gif binary data -->
                </div>
              </div>
            <% end %>
          </div>
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