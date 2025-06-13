defmodule NathanForUsWeb.Components.VideoTimeline.TimelineControls do
  @moduledoc """
  Timeline playback and zoom controls.
  """
  
  use NathanForUsWeb, :html
  
  @doc """
  Renders timeline control buttons and settings.
  """
  attr :timeline_position, :float, required: true
  attr :timeline_playing, :boolean, required: true
  attr :playback_speed, :float, required: true
  attr :timeline_zoom, :float, required: true
  attr :frame_count, :integer, required: true
  attr :video_duration_ms, :integer, required: true
  
  def timeline_controls(assigns) do
    ~H"""
    <div class="bg-gray-800 border-b border-gray-700 px-6 py-3">
      <div class="flex items-center justify-between">
        <!-- Playback Controls (disabled due to server crashes) -->
        <div class="flex items-center gap-4">
          <%!-- Play/Pause Button (hidden to prevent crashes)
          <button
            phx-click="toggle_playback"
            class="flex items-center justify-center w-10 h-10 rounded-full bg-blue-600 hover:bg-blue-700 transition-colors"
          >
            <%= if @timeline_playing do %>
              <!-- Pause Icon -->
              <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
              </svg>
            <% else %>
              <!-- Play Icon -->
              <svg class="w-5 h-5 text-white ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z"/>
              </svg>
            <% end %>
          </button>
          
          <!-- Speed Control -->
          <div class="flex items-center gap-2">
            <label class="text-sm text-gray-300 font-mono">Speed:</label>
            <select
              phx-change="set_playback_speed"
              name="speed"
              class="bg-gray-700 text-white text-sm rounded px-2 py-1 font-mono"
            >
              <option value="0.25" selected={@playback_speed == 0.25}>0.25x</option>
              <option value="0.5" selected={@playback_speed == 0.5}>0.5x</option>
              <option value="1.0" selected={@playback_speed == 1.0}>1x</option>
              <option value="1.5" selected={@playback_speed == 1.5}>1.5x</option>
              <option value="2.0" selected={@playback_speed == 2.0}>2x</option>
              <option value="4.0" selected={@playback_speed == 4.0}>4x</option>
            </select>
          </div>
          --%>
        </div>
        
        <!-- Position Info -->
        <div class="flex items-center gap-6 text-sm font-mono text-gray-300">
          <div>
            Frame: <span class="text-white"><%= round(@timeline_position * @frame_count) %></span>
            <span class="text-gray-500">/ <%= @frame_count %></span>
          </div>
          
          <div>
            Time: <span class="text-white"><%= format_current_time(@timeline_position * @video_duration_ms) %></span>
            <span class="text-gray-500">/ <%= format_duration(@video_duration_ms) %></span>
          </div>
          
          <div>
            Progress: <span class="text-white"><%= Float.round(@timeline_position * 100, 1) %>%</span>
          </div>
        </div>
        
        <!-- Zoom Controls -->
        <div class="flex items-center gap-4">
          <!-- Zoom Control -->
          <div class="flex items-center gap-2">
            <label class="text-sm text-gray-300 font-mono">Zoom:</label>
            <select
              phx-change="zoom_timeline"
              name="zoom"
              class="bg-gray-700 text-white text-sm rounded px-2 py-1 font-mono"
            >
              <option value="0.5" selected={@timeline_zoom == 0.5}>0.5x</option>
              <option value="1.0" selected={@timeline_zoom == 1.0}>1x</option>
              <option value="2.0" selected={@timeline_zoom == 2.0}>2x</option>
              <option value="4.0" selected={@timeline_zoom == 4.0}>4x</option>
              <option value="8.0" selected={@timeline_zoom == 8.0}>8x</option>
            </select>
          </div>
          
          <!-- Reset Button -->
          <button
            phx-click="zoom_timeline"
            phx-value-zoom="1.0"
            class="text-sm text-gray-400 hover:text-white font-mono px-2 py-1 rounded hover:bg-gray-700"
          >
            Reset
          </button>
        </div>
      </div>
    </div>
    """
  end
  
  # Helper functions
  
  defp format_current_time(ms) when is_number(ms) do
    total_seconds = round(ms / 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
  
  defp format_duration(nil), do: "0:00"
  defp format_duration(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
end