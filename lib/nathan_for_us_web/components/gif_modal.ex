defmodule NathanForUsWeb.Components.GifModal do
  @moduledoc """
  Shared GIF modal component for displaying GIFs in a zoomed view with captions.
  """
  
  use NathanForUsWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50" phx-click="close_gif_modal">
      <div class="bg-gray-800 rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto border border-gray-600" phx-click-away="close_gif_modal">
        <div class="p-6">
          <!-- Header with close button -->
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-bold font-mono text-white">
              <%= @gif_data.title || "Nathan GIF" %>
            </h2>
            <button
              phx-click="close_gif_modal"
              class="text-gray-400 hover:text-white transition-colors"
              title="Close"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>

          <!-- GIF Display -->
          <div class="text-center mb-6">
            <div class="inline-block bg-gray-700 rounded-lg overflow-hidden border border-gray-600">
              <%= if @gif_data.gif && @gif_data.gif.gif_data do %>
                <img
                  src={"data:image/gif;base64,#{NathanForUs.Gif.to_base64(@gif_data.gif)}"}
                  alt={@gif_data.title || "Nathan GIF"}
                  class="max-w-full max-h-[60vh] object-contain"
                />
              <% else %>
                <div class="w-96 h-56 flex items-center justify-center text-gray-400 font-mono">
                  <div class="text-center">
                    <div>Nathan GIF</div>
                    <div class="text-xs mt-1">No data available</div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- GIF Metadata -->
          <div class="bg-gray-700 rounded-lg p-4 mb-6">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm font-mono">
              <div>
                <span class="text-gray-400">Episode:</span>
                <span class="text-white ml-2"><%= @gif_data.video.title %></span>
              </div>
              <%= if @gif_data.category do %>
                <div>
                  <span class="text-gray-400">Category:</span>
                  <span class="text-white ml-2 capitalize"><%= String.replace(@gif_data.category, "_", " ") %></span>
                </div>
              <% end %>
              <%= if @gif_data.gif && @gif_data.gif.frame_count do %>
                <div>
                  <span class="text-gray-400">Frames:</span>
                  <span class="text-white ml-2"><%= @gif_data.gif.frame_count %></span>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Captions Section -->
          <%= if length(@captions) > 0 do %>
            <div class="bg-gray-700 rounded-lg p-4">
              <h3 class="text-lg font-bold font-mono text-blue-400 mb-4">
                💬 Captions from this moment
              </h3>
              <div class="space-y-3 max-h-48 overflow-y-auto">
                <%= for caption <- @captions do %>
                  <div class="bg-gray-600 rounded-lg p-3">
                    <p class="text-gray-200 leading-relaxed font-mono text-sm">
                      "<%= caption %>"
                    </p>
                  </div>
                <% end %>
              </div>
            </div>
          <% else %>
            <div class="bg-gray-700 rounded-lg p-4">
              <h3 class="text-lg font-bold font-mono text-blue-400 mb-4">
                💬 Captions
              </h3>
              <p class="text-gray-400 font-mono text-sm italic">
                No captions found for this GIF moment.
              </p>
            </div>
          <% end %>

          <!-- Action Buttons -->
          <div class="flex items-center justify-center gap-4 mt-6 pt-4 border-t border-gray-600">
            <button
              phx-click="close_gif_modal" 
              class="bg-gray-600 hover:bg-gray-700 text-white px-6 py-2 rounded-lg font-mono transition-colors"
            >
              Close
            </button>
            
            <%= if @show_share_button do %>
              <button
                phx-click="share_gif"
                phx-value-gif_id={@gif_data.id}
                class="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded-lg font-mono transition-colors"
              >
                📤 Repost to Timeline
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end