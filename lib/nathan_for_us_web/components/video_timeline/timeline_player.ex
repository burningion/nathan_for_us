defmodule NathanForUsWeb.Components.VideoTimeline.TimelinePlayer do
  @moduledoc """
  Interactive timeline scrubber component for video navigation.
  """

  use NathanForUsWeb, :html

  @doc """
  Renders the main timeline player with scrubber.
  """
  attr :timeline_position, :float, required: true
  attr :timeline_zoom, :float, default: 1.0
  attr :frame_count, :integer, required: true
  attr :video_duration_ms, :integer, required: true
  attr :video, :map, required: true

  def timeline_player(assigns) do
    ~H"""
    <div class="bg-gray-800 border-b border-gray-700">
      <div class="px-6 py-4">
        <!-- Timeline Container -->
        <div class="relative">
          <!-- Timeline Track -->
          <div
            id="timeline-track"
            phx-hook="TimelineScrubber"
            class="relative h-16 bg-gray-700 rounded-lg cursor-pointer select-none overflow-hidden"
            data-position={@timeline_position}
            style={"transform: scaleX(#{@timeline_zoom}); transform-origin: left;"}
          >
            <!-- Timeline Background Pattern -->
            <div class="absolute inset-0 timeline-background"></div>
            
    <!-- Timeline Markers -->
            <div class="absolute inset-0 flex items-center">
              <%= for marker <- timeline_markers(@frame_count, @video_duration_ms) do %>
                <div
                  class="absolute h-full border-l border-gray-500 flex items-end pb-1"
                  style={"left: #{marker.position * 100}%;"}
                >
                  <span class="text-xs text-gray-400 font-mono transform -rotate-45 origin-bottom-left ml-1">
                    {marker.label}
                  </span>
                </div>
              <% end %>
            </div>
            
    <!-- Scrubber Handle -->
            <div
              class="absolute top-0 h-full w-1 bg-blue-500 shadow-lg timeline-scrubber"
              style={"left: #{@timeline_position * 100}%;"}
            >
              <!-- Scrubber Thumb -->
              <div class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-4 h-8 bg-blue-500 rounded-full border-2 border-white shadow-lg cursor-grab active:cursor-grabbing">
              </div>
              
    <!-- Position Line -->
              <div class="absolute top-0 left-1/2 transform -translate-x-1/2 w-0.5 h-full bg-blue-400">
              </div>
            </div>
            
    <!-- Timeline Info Tooltip -->
            <div
              class="absolute -top-12 bg-gray-900 text-white px-2 py-1 rounded text-sm font-mono whitespace-nowrap pointer-events-none timeline-tooltip"
              style={"left: #{@timeline_position * 100}%; transform: translateX(-50%);"}
            >
              Frame {round(@timeline_position * @frame_count)} • {format_timeline_time(
                @timeline_position * @video_duration_ms
              )}
            </div>
          </div>
          
    <!-- Timeline Scale -->
          <div class="mt-2 flex justify-between text-xs text-gray-400 font-mono">
            <span>0:00</span>
            <span>Frame {@frame_count}</span>
            <span>{format_duration(@video_duration_ms)}</span>
          </div>
        </div>
      </div>
    </div>

    <style>
      .timeline-background {
        background: linear-gradient(90deg, 
          #374151 0%, 
          #4b5563 25%, 
          #374151 50%, 
          #4b5563 75%, 
          #374151 100%
        );
        background-size: 40px 100%;
        opacity: 0.3;
      }

      .timeline-scrubber:hover .timeline-tooltip {
        opacity: 1;
      }

      .timeline-tooltip {
        opacity: 0;
        transition: opacity 0.2s ease;
      }

      #timeline-track:hover .timeline-tooltip {
        opacity: 1;
      }
    </style>
    """
  end

  # Helper functions

  defp timeline_markers(frame_count, duration_ms) do
    # Create markers at regular intervals
    marker_count = 10

    Enum.map(0..marker_count, fn i ->
      position = i / marker_count
      frame_number = round(position * frame_count)
      timestamp = round(position * duration_ms)

      %{
        position: position,
        label: "#{frame_number}",
        timestamp: timestamp
      }
    end)
  end

  defp format_timeline_time(ms) when is_number(ms) do
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
