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
  attr :is_context_view, :boolean, default: false
  attr :is_caption_filtered, :boolean, default: false
  attr :expand_count, :integer, default: 3
  
  def frame_display(assigns) do
    ~H"""
    <div class="flex-1 p-6" phx-hook="FrameMultiSelect" id="frame-grid-container">
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
          <!-- Context View Instructions -->
          <%= if @is_context_view do %>
            <div class="mb-6 p-4 bg-gray-700 rounded-lg border border-gray-600">
              <h4 class="text-sm font-bold text-blue-400 mb-3 uppercase tracking-wide">Context View Controls</h4>
              
              <!-- Legend -->
              <div class="flex flex-wrap gap-4 text-xs font-mono mb-4">
                <div class="flex items-center gap-2">
                  <div class="w-4 h-4 rounded border-2 border-yellow-500 bg-yellow-900/20"></div>
                  <span class="text-gray-300">TARGET: Original search result</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-4 h-4 rounded border-2 border-blue-500 bg-blue-900/20"></div>
                  <span class="text-gray-300">BEFORE: Frames before target</span>
                </div>
                <div class="flex items-center gap-2">
                  <div class="w-4 h-4 rounded border-2 border-green-500 bg-green-900/20"></div>
                  <span class="text-gray-300">AFTER: Frames after target</span>
                </div>
              </div>
              
              <!-- Expand Controls -->
              <div class="border-t border-gray-600 pt-3">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <button
                      phx-click="expand_context_left"
                      class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-2 rounded font-mono text-xs transition-colors flex items-center gap-1"
                      title="Add frames to the left"
                    >
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
                      </svg>
                      ← ADD
                    </button>
                    
                    <span class="text-gray-400 text-xs font-mono">|</span>
                    
                    <button
                      phx-click="expand_context_right"
                      class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-2 rounded font-mono text-xs transition-colors flex items-center gap-1"
                      title="Add frames to the right"
                    >
                      ADD →
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
                      </svg>
                    </button>
                  </div>
                  
                  <div class="flex items-center gap-2">
                    <label class="text-xs text-gray-400 font-mono">Frames:</label>
                    <input
                      type="number"
                      value={@expand_count}
                      min="1"
                      max="20"
                      phx-change="update_expand_count"
                      name="expand_count"
                      class="w-16 bg-gray-600 border border-gray-500 text-white px-2 py-1 rounded font-mono text-xs focus:outline-none focus:border-blue-500"
                    />
                  </div>
                </div>
                
                <p class="text-xs text-gray-400 mt-2">
                  💡 Expand context in either direction to fine-tune your GIF selection
                </p>
              </div>
            </div>
          <% end %>
          
          <!-- Caption Filter Instructions -->
          <%= if @is_caption_filtered and not @is_context_view do %>
            <div class="mb-6 p-4 bg-gray-700 rounded-lg border border-gray-600">
              <h4 class="text-sm font-bold text-blue-400 mb-2 uppercase tracking-wide">Caption Search Results</h4>
              <p class="text-xs text-gray-300 font-mono">
                💡 Click any frame image (not the checkbox) to see 5 frames before and after for better GIF context
              </p>
            </div>
          <% end %>
          
          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8 gap-4">
            <%= for {frame, index} <- Enum.with_index(@current_frames) do %>
              <.frame_card 
                frame={frame} 
                index={index} 
                selected={index in @selected_frame_indices}
                is_context_view={@is_context_view}
                is_caption_filtered={@is_caption_filtered}
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
  attr :is_context_view, :boolean, default: false
  attr :is_caption_filtered, :boolean, default: false
  
  def frame_card(assigns) do
    ~H"""
    <div class={[
      "relative bg-gray-800 rounded-lg overflow-hidden cursor-pointer transition-all duration-200 group frame-card",
      get_frame_ring_class(@frame, @is_context_view, @selected)
    ]}>
      <!-- Selection Checkbox -->
      <div class="absolute top-2 left-2 z-10">
        <button
          phx-click="select_frame"
          phx-value-frame_index={@index}
          phx-value-shift_key="false"
          class={[
            "w-6 h-6 rounded border-2 flex items-center justify-center transition-colors frame-select-btn",
            @selected && "bg-blue-500 border-blue-500" || "bg-gray-700/80 border-gray-500 group-hover:border-blue-400"
          ]}
          data-frame-index={@index}
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
        phx-click={if @is_caption_filtered and not @is_context_view, do: "select_frame", else: "show_frame_modal"}
        phx-value-frame_index={@index}
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
      
      <!-- Context Type Indicator -->
      <%= if @is_context_view and Map.has_key?(@frame, :context_type) do %>
        <div class="absolute top-2 right-2 z-10">
          <%= case @frame.context_type do %>
            <% :target -> %>
              <div class="bg-yellow-500 text-black text-xs font-bold px-2 py-1 rounded font-mono">
                TARGET
              </div>
            <% :before -> %>
              <div class="bg-blue-500 text-white text-xs font-bold px-2 py-1 rounded font-mono">
                BEFORE
              </div>
            <% :after -> %>
              <div class="bg-green-500 text-white text-xs font-bold px-2 py-1 rounded font-mono">
                AFTER
              </div>
            <% _ -> %>
          <% end %>
        </div>
      <% end %>
      
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
        
        <!-- Caption Text Preview -->
        <%= if Map.has_key?(@frame, :caption_texts) and @frame.caption_texts do %>
          <div class="text-blue-300 font-mono text-xs mt-2 truncate" title={@frame.caption_texts}>
            📝 <%= String.slice(@frame.caption_texts, 0, 30) %><%= if String.length(@frame.caption_texts) > 30, do: "..." %>
          </div>
        <% end %>
      </div>
      
      <!-- Hover Overlay -->
      <div class="absolute inset-0 bg-blue-500/10 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none"></div>
      
      <!-- Drag Selection Overlay -->
      <div class="absolute inset-0 bg-blue-500/20 opacity-0 transition-opacity pointer-events-none drag-selection-overlay"></div>
    </div>
    
    <style>
      .frame-card.drag-selecting {
        transform: scale(0.95);
        box-shadow: 0 0 0 2px #3b82f6;
      }
      
      .frame-card.drag-selecting .drag-selection-overlay {
        opacity: 1 !important;
      }
    </style>
    """
  end
  
  # Helper functions

  defp get_frame_ring_class(frame, is_context_view, selected) do
    cond do
      selected ->
        "ring-2 ring-blue-500 bg-blue-900/20 hover:ring-2 hover:ring-blue-500"
      
      is_context_view and Map.has_key?(frame, :context_type) ->
        case frame.context_type do
          :target -> "ring-2 ring-yellow-500 bg-yellow-900/20 hover:ring-2 hover:ring-yellow-400"
          :before -> "ring-2 ring-blue-500 bg-blue-900/20 hover:ring-2 hover:ring-blue-400"
          :after -> "ring-2 ring-green-500 bg-green-900/20 hover:ring-2 hover:ring-green-400"
          _ -> "hover:ring-2 hover:ring-blue-500"
        end
      
      true ->
        "hover:ring-2 hover:ring-blue-500"
    end
  end
  
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