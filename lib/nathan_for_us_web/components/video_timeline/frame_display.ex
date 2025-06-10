defmodule NathanForUsWeb.Components.VideoTimeline.FrameDisplay do
  @moduledoc """
  Frame grid display component for timeline browser.
  """
  
  use NathanForUsWeb, :html
  
  @doc """
  Renders the frame grid showing current timeline position frames.
  """
  attr :current_frames, :list, required: true
  attr :loading_frames, :boolean, required: true
  attr :selected_frame_indices, :list, required: true
  attr :timeline_position, :float, required: true
  
  def frame_display(assigns) do
    ~H"""
    <div class="flex-1 p-6">
      <!-- Loading State -->
      <%= if @loading_frames do %>
        <div class="flex items-center justify-center h-64">
          <div class="flex items-center gap-3 text-gray-400">
            <svg class="animate-spin h-6 w-6" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span class="font-mono">Loading frames...</span>
          </div>
        </div>
      <% else %>
        <!-- Frame Grid -->
        <%= if length(@current_frames) > 0 do %>
          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8 gap-4">
            <%= for {frame, index} <- Enum.with_index(@current_frames) do %>
              <.frame_card 
                frame={frame} 
                index={index} 
                selected={index in @selected_frame_indices}
              />
            <% end %>
          </div>
          
          <!-- Selection Info -->
          <%= if length(@selected_frame_indices) > 0 do %>
            <div class="mt-6 p-4 bg-blue-900/20 border border-blue-700 rounded-lg">
              <div class="flex items-center justify-between">
                <div class="text-blue-300 font-mono text-sm">
                  <%= length(@selected_frame_indices) %> frames selected
                </div>
                
                <button
                  phx-click="create_sequence_from_selection"
                  class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded font-mono text-sm"
                >
                  Create Sequence →
                </button>
              </div>
            </div>
          <% end %>
        <% else %>
          <!-- Empty State -->
          <div class="flex items-center justify-center h-64">
            <div class="text-center text-gray-400">
              <svg class="w-16 h-16 mx-auto mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h3a1 1 0 110 2h-1v12a3 3 0 01-3 3H7a3 3 0 01-3-3V6H3a1 1 0 110-2h4zM6 6v12a1 1 0 001 1h10a1 1 0 001-1V6H6z"></path>
              </svg>
              <p class="font-mono">No frames found at this position</p>
              <p class="text-sm mt-2">Try moving the timeline scrubber</p>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders an individual frame card.
  """
  attr :frame, :map, required: true
  attr :index, :integer, required: true
  attr :selected, :boolean, default: false
  
  def frame_card(assigns) do
    ~H"""
    <div class={[
      "relative bg-gray-800 rounded-lg overflow-hidden cursor-pointer transition-all duration-200 hover:ring-2 hover:ring-blue-500 group",
      @selected && "ring-2 ring-blue-500 bg-blue-900/20"
    ]}>
      <!-- Selection Checkbox -->
      <div class="absolute top-2 left-2 z-10">
        <button
          phx-click="select_frame"
          phx-value-frame_index={@index}
          class={[
            "w-6 h-6 rounded border-2 flex items-center justify-center transition-colors",
            @selected && "bg-blue-500 border-blue-500" || "bg-gray-700/80 border-gray-500 group-hover:border-blue-400"
          ]}
        >
          <%= if @selected do %>
            <svg class="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
            </svg>
          <% end %>
        </button>
      </div>
      
      <!-- Frame Image -->
      <button
        phx-click="show_frame_modal"
        phx-value-frame_id={@frame.id}
        class="w-full"
      >
        <div class="aspect-video bg-gray-700 relative overflow-hidden">
          <%= if @frame.image_data do %>
            <img
              src={"data:image/jpeg;base64,#{encode_frame_image(@frame.image_data)}"}
              alt={"Frame ##{@frame.frame_number}"}
              class="w-full h-full object-cover"
            />
          <% else %>
            <div class="w-full h-full flex items-center justify-center text-gray-500">
              <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
              </svg>
            </div>
          <% end %>
        </div>
      </button>
      
      <!-- Frame Info -->
      <div class="p-3">
        <div class="flex items-center justify-between">
          <div class="text-white font-mono text-sm font-bold">
            #<%= @frame.frame_number %>
          </div>
          
          <div class="text-gray-400 font-mono text-xs">
            <%= format_timestamp(@frame.timestamp_ms) %>
          </div>
        </div>
        
        <%= if @frame.width != nil and @frame.height != nil do %>
          <div class="text-gray-500 font-mono text-xs mt-1">
            <%= @frame.width %>×<%= @frame.height %>
          </div>
        <% end %>
      </div>
      
      <!-- Hover Overlay -->
      <div class="absolute inset-0 bg-blue-500/10 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none"></div>
    </div>
    """
  end
  
  # Helper functions
  
  defp format_timestamp(nil), do: "0:00"
  defp format_timestamp(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
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