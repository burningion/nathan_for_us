defmodule NathanForUsWeb.Components.VideoSearch.FrameSequence do
  @moduledoc """
  Frame sequence modal component for viewing and animating frame sequences.
  """
  
  use NathanForUsWeb, :html
  
  @doc """
  Renders the frame sequence modal.
  """
  attr :frame_sequence, :map, required: true
  attr :selected_frame_indices, :list, required: true
  attr :animation_speed, :integer, default: 150
  
  def frame_sequence_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50" phx-click="close_sequence_modal">
      <div class="bg-white rounded-lg shadow-xl max-w-7xl w-full mx-4 max-h-[95vh] overflow-y-auto" phx-click-away="close_sequence_modal">
        <div class="p-4">
          <.modal_header frame_sequence={@frame_sequence} />
          
          <.compact_animation_section 
            frame_sequence={@frame_sequence}
            selected_frame_indices={@selected_frame_indices}
            animation_speed={@animation_speed}
          />
          
          <.frame_sequence_grid 
            frame_sequence={@frame_sequence}
            selected_frame_indices={@selected_frame_indices}
          />
          
          <.compact_info_footer 
            frame_sequence={@frame_sequence}
            selected_frame_indices={@selected_frame_indices}
            animation_speed={@animation_speed}
          />
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders the modal header.
  """
  attr :frame_sequence, :map, required: true
  
  def modal_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-3">
      <div>
        <h2 class="text-lg font-bold text-zinc-900 font-mono">FRAME SEQUENCE • #<%= @frame_sequence.target_frame.frame_number %></h2>
        <p class="text-xs text-zinc-600 font-mono">
          Surrounding frames (± 5) • Full resolution animation
        </p>
      </div>
      <button
        phx-click="close_sequence_modal"
        class="text-zinc-500 hover:text-zinc-700 transition-colors"
      >
        <.icon name="hero-x-mark" class="w-5 h-5" />
      </button>
    </div>
    """
  end
  
  @doc """
  Renders target frame context information.
  """
  attr :frame_sequence, :map, required: true
  
  def target_frame_context(assigns) do
    ~H"""
    <div class="mb-6 p-4 bg-blue-50 border border-blue-200 rounded font-mono text-sm">
      <div class="text-blue-600 uppercase mb-2">TARGET FRAME CONTEXT</div>
      <div class="text-blue-900">
        <div class="mb-1">Timestamp: <%= format_timestamp(@frame_sequence.target_frame.timestamp_ms) %></div>
        <%= if @frame_sequence.target_captions != "" do %>
          <div class="border-l-2 border-blue-600 pl-3 mt-2">
            "<%= @frame_sequence.target_captions %>"
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders the compact animation section with context and preview.
  """
  attr :frame_sequence, :map, required: true
  attr :selected_frame_indices, :list, required: true
  attr :animation_speed, :integer, default: 150
  
  def compact_animation_section(assigns) do
    ~H"""
    <div class="mb-4 bg-zinc-900 rounded-lg p-4">
      <!-- Top row: Context info and controls -->
      <div class="flex items-start justify-between mb-3">
        <div class="text-blue-300 text-xs font-mono">
          <div class="mb-1">TIMESTAMP: <%= format_timestamp(@frame_sequence.target_frame.timestamp_ms) %></div>
          <%= if @frame_sequence.target_captions != "" do %>
            <div class="text-blue-100 italic">
              "<%= String.slice(@frame_sequence.target_captions, 0, 80) %><%= if String.length(@frame_sequence.target_captions) > 80, do: "..." %>"
            </div>
          <% end %>
        </div>
        <div class="text-white text-xs font-mono text-right">
          <div>🎬 ANIMATING <%= length(@selected_frame_indices) %>/<%= length(@frame_sequence.sequence_frames) %></div>
          <div class="text-zinc-400">FULL RES • USER CONTROLLED</div>
        </div>
      </div>
      
      <!-- Animation controls -->
      <div class="mb-3 flex items-center gap-4">
        <div class="flex items-center gap-2">
          <button 
            phx-click="select_all_frames"
            class="bg-blue-600 hover:bg-blue-700 text-white text-xs px-2 py-1 rounded"
          >
            ALL
          </button>
          <button 
            phx-click="deselect_all_frames"
            class="bg-red-600 hover:bg-red-700 text-white text-xs px-2 py-1 rounded"
          >
            NONE
          </button>
        </div>
        
        <!-- Animation speed control -->
        <div class="flex items-center gap-2 bg-zinc-800 px-3 py-1 rounded">
          <label class="text-zinc-300 text-xs font-mono">SPEED:</label>
          <input 
            type="range" 
            min="50" 
            max="1000" 
            value={@animation_speed} 
            step="25"
            phx-hook="AnimationSpeedSlider"
            phx-click-away="ignore"
            class="w-24 h-2 bg-zinc-600 rounded-lg appearance-none cursor-pointer slider"
            id="speed-slider"
            data-animation-container={"animation-container-#{@frame_sequence.target_frame.id}"}
            onmousedown="event.stopPropagation()"
            onmouseup="event.stopPropagation()"
            onclick="event.stopPropagation()"
          />
          <span class="text-zinc-300 text-xs font-mono w-8" id="speed-display"><%= @animation_speed %>ms</span>
        </div>
        
        <div class="text-zinc-400 text-xs">
          Click frames below to toggle animation
        </div>
      </div>
      
      <!-- Animation container -->
      <.animation_container 
        frame_sequence={@frame_sequence}
        selected_frame_indices={@selected_frame_indices}
        animation_speed={@animation_speed}
      />
    </div>
    """
  end

  @doc """
  Renders the animated GIF preview section.
  """
  attr :frame_sequence, :map, required: true
  attr :selected_frame_indices, :list, required: true
  
  def animation_preview(assigns) do
    ~H"""
    <div class="mb-8 bg-zinc-900 rounded-lg p-6">
      <div class="text-white uppercase mb-4 font-mono text-sm flex items-center justify-between">
        <span>🎬 ANIMATED PREVIEW</span>
        <span class="text-xs text-zinc-400">
          Animating <%= length(@selected_frame_indices) %> of <%= length(@frame_sequence.sequence_frames) %> frames
        </span>
      </div>
      
      <.selection_controls />
      
      <.animation_container 
        frame_sequence={@frame_sequence}
        selected_frame_indices={@selected_frame_indices}
      />
      
      <.selected_frames_captions 
        frame_sequence={@frame_sequence}
        selected_frame_indices={@selected_frame_indices}
      />
      
      <div class="text-center mt-4">
        <p class="text-zinc-400 text-sm font-mono">Click frames below to control which ones animate</p>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders frame selection controls.
  """
  def selection_controls(assigns) do
    ~H"""
    <div class="mb-4 p-3 bg-zinc-800 rounded border border-zinc-700">
      <div class="text-zinc-300 text-xs uppercase mb-2">FRAME SELECTION CONTROLS</div>
      <div class="flex items-center gap-4">
        <button 
          phx-click="select_all_frames"
          class="bg-blue-600 hover:bg-blue-700 text-white text-xs px-3 py-1 rounded"
        >
          SELECT ALL
        </button>
        <button 
          phx-click="deselect_all_frames"
          class="bg-red-600 hover:bg-red-700 text-white text-xs px-3 py-1 rounded"
        >
          DESELECT ALL
        </button>
        <div class="text-zinc-400 text-xs ml-4">
          Click individual frames below to toggle them in/out of animation
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders the animation container with frame images.
  """
  attr :frame_sequence, :map, required: true
  attr :selected_frame_indices, :list, required: true
  attr :animation_speed, :integer, default: 150
  
  def animation_container(assigns) do
    first_frame = List.first(assigns.frame_sequence.sequence_frames)
    
    # Get frame dimensions with fallbacks for nil values
    frame_width = case Map.get(first_frame, :width) do
      nil -> 1920  # Default to 1920 if nil
      width when is_integer(width) and width > 0 -> width
      _ -> 1920
    end
    
    frame_height = case Map.get(first_frame, :height) do
      nil -> 1080  # Default to 1080 if nil
      height when is_integer(height) and height > 0 -> height
      _ -> 1080
    end
    
    # Calculate aspect ratio and set more compact size constraints
    aspect_ratio = frame_width / frame_height
    max_width = min(600, frame_width)  # Smaller max width for compact view
    calculated_height = round(max_width / aspect_ratio)
    
    assigns = assign(assigns, :container_style, "width: #{max_width}px; height: #{calculated_height}px")
    
    ~H"""
    <div class="flex justify-center">
      <div class="relative bg-black rounded-lg overflow-hidden">
        <div 
          id={"animation-container-#{@frame_sequence.target_frame.id}"}
          class="relative"
          style={@container_style}
          phx-hook="FrameAnimator"
          data-frames={Jason.encode!(Enum.map(@frame_sequence.sequence_frames, fn frame -> 
            if Map.get(frame, :image_data) do
              "data:image/jpeg;base64,#{encode_image_data(frame.image_data)}"
            else
              nil
            end
          end))}
          data-selected-indices={Jason.encode!(@selected_frame_indices)}
          data-frame-timestamps={Jason.encode!(Enum.map(@frame_sequence.sequence_frames, fn frame -> 
            Map.get(frame, :timestamp_ms, 0)
          end))}
          data-animation-speed={@animation_speed}
        >
          <%= for {frame, index} <- Enum.with_index(@frame_sequence.sequence_frames) do %>
            <%= if Map.get(frame, :image_data) do %>
              <img
                id={"anim-frame-#{frame.id}"}
                src={"data:image/jpeg;base64,#{encode_image_data(frame.image_data)}"}
                alt={"Frame ##{frame.frame_number}"}
                class={[
                  "absolute inset-0 w-full h-full object-cover transition-opacity duration-50",
                  if(index == Enum.at(@selected_frame_indices, 0, 0), do: "opacity-100", else: "opacity-0")
                ]}
                data-frame-index={index}
              />
            <% end %>
          <% end %>
          
          <!-- Animation overlay info -->
          <div class="absolute bottom-2 left-2 bg-black/70 text-white px-2 py-1 rounded text-xs font-mono">
            FULL RES • LIFELIKE SPEED
          </div>
          
          <!-- Frame counter -->
          <div id={"frame-counter-#{@frame_sequence.target_frame.id}"} class="absolute bottom-2 right-2 bg-black/70 text-white px-2 py-1 rounded text-xs font-mono">
            1/<%= length(@selected_frame_indices) %>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders selected frames captions.
  """
  attr :frame_sequence, :map, required: true
  attr :selected_frame_indices, :list, required: true
  
  def selected_frames_captions(assigns) do
    ~H"""
    <div class="mt-6 p-4 bg-zinc-800 rounded border border-zinc-700">
      <div class="text-zinc-300 text-xs uppercase mb-3 font-mono">🎬 SELECTED FRAMES DIALOGUE</div>
      <div class="text-zinc-100 text-sm leading-relaxed font-mono">
        <%= get_selected_frames_captions(@frame_sequence, @selected_frame_indices) %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders the frame sequence grid.
  """
  attr :frame_sequence, :map, required: true
  attr :selected_frame_indices, :list, required: true
  
  def frame_sequence_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-3 md:grid-cols-6 lg:grid-cols-8 gap-2">
      <!-- Expand backward button -->
      <.expand_backward_button />
      
      <%= for {frame, index} <- Enum.with_index(@frame_sequence.sequence_frames) do %>
        <.frame_grid_item 
          frame={frame}
          index={index}
          target_frame_id={@frame_sequence.target_frame.id}
          selected_frame_indices={@selected_frame_indices}
        />
      <% end %>
      
      <!-- Expand forward button -->
      <.expand_forward_button />
    </div>
    """
  end
  
  @doc """
  Renders expand backward button (adds previous frame).
  """
  def expand_backward_button(assigns) do
    ~H"""
    <div class="border-2 border-dashed border-zinc-300 rounded-lg overflow-hidden cursor-pointer hover:border-blue-400 hover:bg-blue-50 transition-all aspect-video bg-zinc-50 flex items-center justify-center"
         phx-click="expand_sequence_backward"
         title="Add previous frame to sequence">
      <div class="text-center">
        <div class="text-2xl text-zinc-400 hover:text-blue-500 mb-1">−</div>
        <div class="text-xs text-zinc-500 font-mono">EXPAND</div>
        <div class="text-xs text-zinc-400 font-mono">BACK</div>
      </div>
    </div>
    """
  end

  @doc """
  Renders expand forward button (adds next frame).
  """
  def expand_forward_button(assigns) do
    ~H"""
    <div class="border-2 border-dashed border-zinc-300 rounded-lg overflow-hidden cursor-pointer hover:border-blue-400 hover:bg-blue-50 transition-all aspect-video bg-zinc-50 flex items-center justify-center"
         phx-click="expand_sequence_forward"
         title="Add next frame to sequence">
      <div class="text-center">
        <div class="text-2xl text-zinc-400 hover:text-blue-500 mb-1">+</div>
        <div class="text-xs text-zinc-500 font-mono">EXPAND</div>
        <div class="text-xs text-zinc-400 font-mono">NEXT</div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an individual frame in the grid.
  """
  attr :frame, :map, required: true
  attr :index, :integer, required: true
  attr :target_frame_id, :integer, required: true
  attr :selected_frame_indices, :list, required: true
  
  def frame_grid_item(assigns) do
    ~H"""
    <div class={[
      "border rounded-lg overflow-hidden cursor-pointer hover:shadow-lg transition-all",
      cond do
        @frame.id == @target_frame_id and @index in @selected_frame_indices -> 
          "border-blue-500 border-2 bg-blue-50 ring-2 ring-blue-200"
        @frame.id == @target_frame_id -> 
          "border-blue-300 border-2 bg-blue-25 ring-1 ring-blue-100 opacity-60"
        @index in @selected_frame_indices -> 
          "border-blue-500 border-2 bg-blue-50"
        true -> 
          "border-zinc-300 hover:border-zinc-400 opacity-60"
      end
    ]}
    phx-click="toggle_frame_selection"
    phx-value-frame_index={@index}
    title={if @index in @selected_frame_indices, do: "Click to remove from animation", else: "Click to add to animation"}
    >
      <.frame_grid_image frame={@frame} target_frame_id={@target_frame_id} />
      <.frame_grid_info frame={@frame} />
      <.frame_grid_indicators 
        frame={@frame}
        index={@index}
        target_frame_id={@target_frame_id}
        selected_frame_indices={@selected_frame_indices}
      />
    </div>
    """
  end
  
  @doc """
  Renders frame image in grid.
  """
  attr :frame, :map, required: true
  attr :target_frame_id, :integer, required: true
  
  def frame_grid_image(assigns) do
    ~H"""
    <div class="aspect-video bg-zinc-100 relative">
      <%= if Map.get(@frame, :image_data) do %>
        <img
          src={"data:image/jpeg;base64,#{encode_image_data(@frame.image_data)}"}
          alt={"Frame ##{@frame.frame_number}"}
          class="w-full h-full object-cover"
        />
      <% else %>
        <div class="w-full h-full flex items-center justify-center text-zinc-400">
          <.icon name="hero-photo" class="w-8 h-8" />
        </div>
      <% end %>
      
      <!-- Frame number overlay -->
      <div class={[
        "absolute bottom-1 right-1 px-1 py-0.5 rounded text-xs font-mono",
        if(@frame.id == @target_frame_id, do: "bg-blue-600 text-white", else: "bg-black/70 text-white")
      ]}>
        #<%= @frame.frame_number %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders frame info in grid.
  """
  attr :frame, :map, required: true
  
  def frame_grid_info(assigns) do
    ~H"""
    <div class="p-1">
      <div class="text-xs text-zinc-500 font-mono text-center">
        <%= format_timestamp(@frame.timestamp_ms) %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders frame indicators (target, selection).
  """
  attr :frame, :map, required: true
  attr :index, :integer, required: true
  attr :target_frame_id, :integer, required: true
  attr :selected_frame_indices, :list, required: true
  
  def frame_grid_indicators(assigns) do
    ~H"""
    <!-- Target frame indicator -->
    <%= if @frame.id == @target_frame_id do %>
      <div class="absolute top-1 left-1 bg-blue-600 text-white px-1 py-0.5 rounded text-xs font-mono">
        TARGET
      </div>
    <% end %>
    
    <!-- Selection indicator -->
    <%= if @index in @selected_frame_indices do %>
      <div class="absolute top-1 right-1 bg-blue-500 text-white rounded-full w-5 h-5 flex items-center justify-center">
        <.icon name="hero-check" class="w-3 h-3" />
      </div>
    <% else %>
      <div class="absolute top-1 right-1 bg-zinc-400 text-white rounded-full w-5 h-5 flex items-center justify-center opacity-50">
        <.icon name="hero-x-mark" class="w-3 h-3" />
      </div>
    <% end %>
    """
  end
  
  @doc """
  Renders sequence information panel.
  """
  attr :frame_sequence, :map, required: true
  
  def sequence_info(assigns) do
    ~H"""
    <div class="mt-6 p-4 bg-zinc-50 border border-zinc-200 rounded font-mono text-sm">
      <div class="text-zinc-600 uppercase mb-2">SEQUENCE INFORMATION</div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-zinc-700">
        <div>
          <div class="text-xs text-zinc-500">FRAMES LOADED</div>
          <div><%= @frame_sequence.sequence_info.total_frames %></div>
        </div>
        <div>
          <div class="text-xs text-zinc-500">FRAME RANGE</div>
          <div>#<%= @frame_sequence.sequence_info.start_frame_number %>-<%= @frame_sequence.sequence_info.end_frame_number %></div>
        </div>
        <div>
          <div class="text-xs text-zinc-500">TARGET FRAME</div>
          <div>#<%= @frame_sequence.sequence_info.target_frame_number %></div>
        </div>
        <div>
          <div class="text-xs text-zinc-500">ANIMATION READY</div>
          <div class="text-blue-600">✓ YES</div>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders animation status panel.
  """
  attr :selected_frame_indices, :list, required: true
  attr :frame_sequence, :map, required: true
  
  def animation_status(assigns) do
    ~H"""
    <div class="mt-4 p-3 bg-green-50 border border-green-200 rounded text-green-800 text-sm font-mono">
      ✅ Animation active - <%= length(@selected_frame_indices) %> of <%= @frame_sequence.sequence_info.total_frames %> frames cycling at lifelike speed (~150ms intervals) for smooth preview
    </div>
    """
  end
  
  @doc """
  Renders compact info footer combining sequence info, status, and legend.
  """
  attr :frame_sequence, :map, required: true
  attr :selected_frame_indices, :list, required: true
  attr :animation_speed, :integer, default: 150
  
  def compact_info_footer(assigns) do
    ~H"""
    <div class="mt-3 p-3 bg-zinc-50 border border-zinc-200 rounded text-zinc-700 text-sm font-mono">
      <div class="flex items-center justify-between text-xs">
        <!-- Sequence info -->
        <div class="flex items-center gap-4">
          <div>
            <span class="text-zinc-500">FRAMES:</span> <%= @frame_sequence.sequence_info.total_frames %>
          </div>
          <div>
            <span class="text-zinc-500">RANGE:</span> #<%= @frame_sequence.sequence_info.start_frame_number %>-<%= @frame_sequence.sequence_info.end_frame_number %>
          </div>
          <div>
            <span class="text-zinc-500">TARGET:</span> #<%= @frame_sequence.sequence_info.target_frame_number %>
          </div>
        </div>
        
        <!-- Status and legend -->
        <div class="flex items-center gap-4">
          <div class="text-green-600">
            ✅ <%= length(@selected_frame_indices) %>/<%= @frame_sequence.sequence_info.total_frames %> animating @ <%= @animation_speed %>ms
          </div>
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 border-2 border-blue-500 bg-blue-50 rounded"></div>
            <span class="text-xs">Target</span>
            <div class="w-3 h-3 border-2 border-blue-500 bg-blue-50 rounded flex items-center justify-center ml-2">
              <.icon name="hero-check" class="w-2 h-2 text-blue-500" />
            </div>
            <span class="text-xs">Selected</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders frame legend.
  """
  def frame_legend(assigns) do
    ~H"""
    <div class="mt-4 p-3 bg-zinc-50 border border-zinc-200 rounded text-zinc-700 text-sm font-mono">
      <div class="text-zinc-600 uppercase mb-2 text-xs">FRAME LEGEND</div>
      <div class="flex flex-wrap gap-4 text-xs">
        <div class="flex items-center gap-2">
          <div class="w-4 h-4 border-2 border-blue-500 bg-blue-50 rounded"></div>
          <span>Target Frame</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-4 h-4 border-2 border-blue-500 bg-blue-50 rounded flex items-center justify-center">
            <.icon name="hero-check" class="w-2 h-2 text-blue-500" />
          </div>
          <span>Selected for Animation</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-4 h-4 border border-zinc-300 bg-white rounded opacity-60"></div>
          <span>Not Selected</span>
        </div>
      </div>
    </div>
    """
  end
  
  # Helper functions
  
  defp format_timestamp(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
  defp format_timestamp(_), do: "0:00"

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      true -> "#{bytes} B"
    end
  end
  defp format_file_size(_), do: "Unknown"

  defp encode_image_data(nil), do: ""
  defp encode_image_data(hex_data) when is_binary(hex_data) do
    # The image data is stored as hex-encoded string starting with \x
    # We need to decode it from hex, then encode to base64
    case String.starts_with?(hex_data, "\\x") do
      true ->
        # Remove the \x prefix and decode from hex
        hex_string = String.slice(hex_data, 2..-1//1)
        case Base.decode16(hex_string, case: :lower) do
          {:ok, binary_data} -> Base.encode64(binary_data)
          :error -> ""
        end
      false ->
        # Already binary data, encode directly
        Base.encode64(hex_data)
    end
  end

  defp get_selected_frames_captions(frame_sequence, selected_frame_indices) do
    NathanForUs.Video.Search.get_selected_frames_captions(frame_sequence, selected_frame_indices)
  end
end