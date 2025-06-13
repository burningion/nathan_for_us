defmodule NathanForUsWeb.Components.VideoTimeline.GifPreview do
  @moduledoc """
  GIF preview component for selected frames on timeline.
  Shows a cycling preview of selected frames to simulate GIF playback.
  """
  
  use NathanForUsWeb, :html
  
  @doc """
  Renders a GIF preview of selected frames.
  """
  attr :current_frames, :list, required: true
  attr :selected_frame_indices, :list, required: true
  attr :gif_generation_status, :atom, default: nil
  attr :generated_gif_data, :string, default: nil
  attr :is_admin, :boolean, default: false
  attr :gif_cache_status, :string, default: nil
  attr :gif_from_cache, :boolean, default: false
  
  def gif_preview(assigns) do
    # Get selected frames based on indices
    selected_frames = 
      assigns.selected_frame_indices
      |> Enum.map(&Enum.at(assigns.current_frames, &1))
      |> Enum.reject(&is_nil/1)
    
    assigns = assign(assigns, :selected_frames, selected_frames)
    
    ~H"""
    <%= if length(@selected_frames) > 1 do %>
      <div class="bg-gray-800 border-b border-gray-700 px-6 py-4">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold font-mono text-white">
            <%= if @gif_generation_status == :completed do %>
              Generated GIF
            <% else %>
              GIF Preview
            <% end %>
          </h3>
          <div class="text-sm font-mono text-gray-400">
            <%= length(@selected_frames) %> frames selected
          </div>
        </div>
        
        <div class="flex justify-center">
          <%= if @gif_generation_status == :completed do %>
            <!-- Show generated GIF -->
            <div class="relative bg-gray-900 rounded-lg overflow-hidden border border-gray-600">
              <img 
                src={"data:image/gif;base64,#{@generated_gif_data}"}
                alt="Generated GIF"
                class="max-w-full max-h-96 rounded"
              />
            </div>
          <% else %>
            <!-- Show preview -->
            <div 
              id="gif-preview-container"
              phx-hook="GifPreview"
              data-frames={Jason.encode!(Enum.map(@selected_frames, &encode_frame_for_preview/1))}
              class="relative bg-gray-900 rounded-lg overflow-hidden border border-gray-600"
              style="width: 400px; height: 225px;"
            >
              <!-- Preview frame will be displayed here by the hook -->
              <div class="absolute inset-0 flex items-center justify-center">
                <div class="text-gray-500 font-mono text-sm">Loading preview...</div>
              </div>
              
              <!-- Frame counter overlay -->
              <div class="absolute bottom-2 right-2 bg-black/70 text-white px-2 py-1 rounded text-xs font-mono">
                <span id="frame-counter">1 / <%= length(@selected_frames) %></span>
              </div>
              
              <!-- Play/pause controls -->
              <div class="absolute bottom-2 left-2 flex gap-2">
                <button 
                  id="gif-play-pause"
                  class="bg-black/70 text-white px-2 py-1 rounded text-xs font-mono hover:bg-black/90"
                >
                  Pause
                </button>
                <select 
                  id="gif-speed"
                  class="bg-black/70 text-white px-1 py-1 rounded text-xs font-mono"
                >
                  <option value="200">Slow</option>
                  <option value="150" selected>Normal</option>
                  <option value="100">Fast</option>
                  <option value="50">Very Fast</option>
                </select>
              </div>
            </div>
          <% end %>
        </div>
        
        <div class="mt-4 text-center">
          <%= if @gif_generation_status == :completed do %>
            <!-- Download and reset buttons -->
            <div class="flex justify-center gap-4">
              <a
                href={"data:image/gif;base64,#{@generated_gif_data}"}
                download="nathan-gif.gif"
                class="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded font-mono text-sm transition-colors"
              >
                Download GIF
              </a>
              
              <button
                phx-click="reset_gif_generation"
                class="bg-gray-600 hover:bg-gray-700 text-white px-6 py-2 rounded font-mono text-sm transition-colors"
              >
                New Preview
              </button>
            </div>
            
            <!-- Admin-only cache status -->
            <%= if @is_admin and @gif_cache_status do %>
              <div class="mt-4 p-3 bg-yellow-900/30 border border-yellow-600/50 rounded-lg">
                <div class="flex items-center justify-center gap-2 mb-2">
                  <span class="text-yellow-400 font-mono text-xs font-bold">⚡ ADMIN DEBUG</span>
                  <%= if @gif_from_cache do %>
                    <span class="bg-green-600 text-white px-2 py-1 rounded text-xs font-mono">CACHED</span>
                  <% else %>
                    <span class="bg-blue-600 text-white px-2 py-1 rounded text-xs font-mono">FRESH</span>
                  <% end %>
                </div>
                <p class="text-yellow-300 text-xs font-mono text-center">
                  <%= @gif_cache_status %>
                </p>
                <div class="text-center mt-2">
                  <span class="text-yellow-400 text-xs font-mono">
                    Cache Hit Rate: High traffic GIFs will load instantly
                  </span>
                </div>
              </div>
            <% end %>
          <% else %>
            <!-- Generation buttons and status -->
            <%= if @gif_generation_status == :generating do %>
              <div class="flex items-center justify-center gap-2">
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-400"></div>
                <p class="text-sm text-blue-400 font-mono">Generating GIF...</p>
              </div>
            <% else %>
              <div class="flex justify-center">
                <button
                  phx-click="generate_timeline_gif_server"
                  class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded font-mono text-sm transition-colors"
                >
                  Generate GIF
                </button>
              </div>
              <p class="text-sm text-gray-400 font-mono mt-2">
                Preview shows how your selected frames will look as a GIF
              </p>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end
  
  # Helper function to encode frame data for JavaScript
  defp encode_frame_for_preview(frame) do
    %{
      id: frame.id,
      frame_number: frame.frame_number,
      timestamp_ms: frame.timestamp_ms,
      image_data: encode_frame_image(frame.image_data)
    }
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
end