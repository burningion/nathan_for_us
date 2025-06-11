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
  attr :frame_sequence_version, :integer, default: 0
  attr :gif_generation_status, :atom, default: nil
  attr :generated_gif_data, :string, default: nil
  attr :ffmpeg_status, :map, default: nil
  attr :client_download_url, :string, default: nil

  def frame_sequence_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg shadow-xl max-w-7xl w-full mx-4 max-h-[95vh] overflow-y-auto">
        <div class="p-4">
          <.modal_header frame_sequence={@frame_sequence} />

          <.compact_animation_section
            frame_sequence={@frame_sequence}
            selected_frame_indices={@selected_frame_indices}
            gif_generation_status={@gif_generation_status}
            generated_gif_data={@generated_gif_data}
            ffmpeg_status={@ffmpeg_status}
            client_download_url={@client_download_url}
            client_gif_enabled={System.get_env("ACTIVATE_CLIENTSIDE_GIF_GENERATION") == "true"}
          />

          <.gif_generation_section
            selected_frame_indices={@selected_frame_indices}
            gif_generation_status={@gif_generation_status}
            generated_gif_data={@generated_gif_data}
            ffmpeg_status={@ffmpeg_status}
            client_download_url={@client_download_url}
          />

          <.frame_sequence_grid
            frame_sequence={@frame_sequence}
            selected_frame_indices={@selected_frame_indices}
            frame_sequence_version={@frame_sequence_version}
          />

          <.compact_info_footer
            frame_sequence={@frame_sequence}
            selected_frame_indices={@selected_frame_indices}
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
  Renders the GIF generation section.
  """
  attr :selected_frame_indices, :list, required: true
  attr :gif_generation_status, :atom, default: nil
  attr :generated_gif_data, :string, default: nil
  attr :ffmpeg_status, :map, default: nil
  attr :client_download_url, :string, default: nil

  def gif_generation_section(assigns) do
    # Check if client-side GIF generation is enabled
    client_gif_enabled = System.get_env("ACTIVATE_CLIENTSIDE_GIF_GENERATION") == "true"
    assigns = assign(assigns, :client_gif_enabled, client_gif_enabled)

    ~H"""
    <div class="mb-4 rounded-lg p-4" phx-hook="ClientGifGenerator" id="gif-generator-video-search">
      <!-- Header with GIF icon and title -->
      <div class="flex items-center gap-3 flex-wrap">
        <%= if @gif_generation_status == :generating do %>
          <button
            disabled
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-purple-700 opacity-50 cursor-not-allowed"
          >
            <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 714 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Generating GIF...
          </button>
        <% else %>
          <%= if @client_gif_enabled do %>
            <!-- Client-side generation (primary) -->
            <button
              phx-click="generate_gif_client"
              disabled={length(@selected_frame_indices) == 0 or @gif_generation_status == :completed}
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h3a1 1 0 110 2h-1v11a3 3 0 01-3 3H7a3 3 0 01-3-3V6H3a1 1 0 110-2h4zM6 6v11a1 1 0 001 1h10a1 1 0 001-1V6H6z"></path>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 11v6M14 11v6"></path>
              </svg>
              <%= if @gif_generation_status == :completed, do: "GIF Created", else: "🚀 Create GIF (Client-side)" %>
            </button>
          <% end %>

          <!-- Server-side generation (now primary when client-side is disabled) -->
          <button
            phx-click="generate_gif_server"
            disabled={length(@selected_frame_indices) == 0 or @gif_generation_status == :completed}
            class={[
              "inline-flex items-center px-4 py-2 border text-sm font-medium rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed",
              if(@client_gif_enabled,
                do: "border-gray-300 text-gray-700 bg-white hover:bg-gray-50 focus:ring-purple-500",
                else: "border-transparent text-white bg-blue-600 hover:bg-blue-700 focus:ring-blue-500"
              )
            ]}
          >
            <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12l7-7m-7 7l7 7"></path>
            </svg>
            <%= if @client_gif_enabled, do: "Server Fallback", else: "🚀 Create GIF" %>
          </button>
        <% end %>

        <%= if @gif_generation_status == :completed and (@generated_gif_data != nil or (@client_gif_enabled and @client_download_url != nil)) do %>
          <%= if @client_gif_enabled and @client_download_url do %>
            <!-- Client-generated GIF download -->
            <a
              href={@client_download_url}
              download={"nathan_#{@selected_frame_indices |> length()}frames.gif"}
              class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors shadow-lg flex items-center gap-2"
              title="Download Client-generated GIF"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3"></path>
              </svg>
              💻 Download GIF
            </a>
          <% end %>
        <% end %>

        <%= if length(@selected_frame_indices) == 0 do %>
          <div class="text-purple-200 text-xs">
            ⚠️ Select frames to enable GIF generation
          </div>
        <% end %>
      </div>
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
  attr :gif_generation_status, :atom, default: nil
  attr :generated_gif_data, :string, default: nil
  attr :ffmpeg_status, :map, default: nil
  attr :client_download_url, :string, default: nil
  attr :client_gif_enabled, :boolean, default: false

  def compact_animation_section(assigns) do
    ~H"""
    <div class="mb-4 bg-zinc-900 rounded-lg p-4">
      <!-- Top row: Context info and controls -->
      <div class="flex items-start justify-between mb-3">
        <div class="text-blue-300 text-xs font-mono">
          <div class="mb-1">TIMESTAMP: <%= format_timestamp(@frame_sequence.target_frame.timestamp_ms) %></div>
        </div>
        <div class="text-white text-xs font-mono text-right">
          <div>🎬 ANIMATING <%= length(@selected_frame_indices) %>/<%= length(@frame_sequence.sequence_frames) %></div>
        </div>
      </div>

      <!-- Animation controls -->
      <div class="mb-3 flex items-center gap-4">
        <div class="text-zinc-400 text-xs">
          Click frames below to toggle animation
        </div>
      </div>

      <!-- Animation container or Generated GIF (replaces animation when GIF is ready) -->
      <div class="flex justify-center">
        <%= if @gif_generation_status == :completed and (@generated_gif_data != nil or (@client_gif_enabled and @client_download_url != nil)) do %>
          <div class="text-center">
            <div class="relative bg-black rounded-lg overflow-hidden mb-4">
              <%= if @client_gif_enabled and @client_download_url do %>
                <!-- Client-generated GIF (blob URL) -->
                <img
                  src={@client_download_url}
                  alt="Generated GIF from selected frames"
                  class="max-w-full max-h-80 rounded"
                  style="width: 600px; height: auto;"
                />
              <% else %>
                <!-- Server-generated GIF (base64 data) -->
                <img
                  src={"data:image/gif;base64,#{@generated_gif_data}"}
                  alt="Generated GIF from selected frames"
                  class="max-w-full max-h-80 rounded"
                  style="width: 600px; height: auto;"
                />
              <% end %>
              <!-- GIF overlay info -->
              <div class="absolute bottom-2 left-2 bg-black/70 text-white px-2 py-1 rounded text-xs font-mono">
                GIF • <%= length(@selected_frame_indices) %> FRAMES
              </div>

              <!-- Download button overlay -->
              <div class="absolute bottom-2 right-2">
                <%= if @client_gif_enabled and @client_download_url do %>
                  <!-- Client-generated GIF download -->
                  <a
                    href={@client_download_url}
                    download={"nathan_#{@frame_sequence.target_frame.frame_number}_#{length(@selected_frame_indices)}frames.gif"}
                    class="bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg text-sm font-mono font-bold transition-colors shadow-lg flex items-center gap-1"
                    title="Download Client-generated GIF"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3"></path>
                    </svg>
                    💻 DOWNLOAD
                  </a>
                <% else %>
                  <!-- Server-generated GIF download -->
                  <a
                    href={"data:image/gif;base64,#{@generated_gif_data}"}
                    download={"nathan_#{@frame_sequence.target_frame.frame_number}_#{length(@selected_frame_indices)}frames.gif"}
                    class="bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg text-sm font-mono font-bold transition-colors shadow-lg flex items-center gap-1"
                    title="Download Server-generated GIF"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3"></path>
                    </svg>
                    🖥️ DOWNLOAD
                  </a>
                <% end %>
              </div>
            </div>

            <!-- Caption underneath GIF -->
            <div class="bg-zinc-800 rounded-lg p-3 max-w-[600px]">
              <div class="text-zinc-300 text-xs uppercase mb-2 font-mono">🎬 DIALOGUE</div>
              <div class="text-zinc-100 text-sm leading-relaxed font-mono text-left">
                <%= get_selected_frames_captions(@frame_sequence, @selected_frame_indices) %>
              </div>
              
              <!-- Share Link -->
              <%= if share_url = NathanForUsWeb.VideoSearchLive.generate_share_url(@frame_sequence, @selected_frame_indices) do %>
                <div class="mt-3 pt-3 border-t border-zinc-600">
                  <div class="flex items-center gap-2 text-xs">
                    <span class="text-zinc-400 font-mono">🔗 SHARE:</span>
                    <input 
                      type="text" 
                      value={"#{NathanForUsWeb.Endpoint.url()}#{share_url}"}
                      readonly
                      class="flex-1 bg-zinc-700 text-zinc-200 px-2 py-1 rounded font-mono text-xs border border-zinc-600 focus:border-blue-500 focus:outline-none select-all"
                      onclick="this.select(); navigator.clipboard.writeText(this.value); this.classList.add('bg-green-700'); setTimeout(() => this.classList.remove('bg-green-700'), 1000);"
                    />
                    <button
                      onclick="navigator.clipboard.writeText(document.querySelector('input[readonly]').value); this.textContent = 'Copied!'; setTimeout(() => this.textContent = 'Copy', 1000);"
                      class="bg-zinc-600 hover:bg-zinc-500 text-zinc-200 px-2 py-1 rounded text-xs font-mono transition-colors"
                    >
                      Copy
                    </button>
                  </div>
                  <div class="text-zinc-500 text-xs mt-1 font-mono">
                    Share this link to show others your selected frames
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="text-center">
            <.animation_container
              frame_sequence={@frame_sequence}
              selected_frame_indices={@selected_frame_indices}
            />

            <!-- Caption underneath animation -->
            <div class="bg-zinc-800 rounded-lg p-3 max-w-[600px] mt-4">
              <div class="text-zinc-300 text-xs uppercase mb-2 font-mono">🎬 DIALOGUE</div>
              <div class="text-zinc-100 text-sm leading-relaxed font-mono text-left">
                <%= get_selected_frames_captions(@frame_sequence, @selected_frame_indices) %>
              </div>
              
              <!-- Share Link -->
              <%= if share_url = NathanForUsWeb.VideoSearchLive.generate_share_url(@frame_sequence, @selected_frame_indices) do %>
                <div class="mt-3 pt-3 border-t border-zinc-600">
                  <div class="flex items-center gap-2 text-xs">
                    <span class="text-zinc-400 font-mono">🔗 SHARE:</span>
                    <input 
                      type="text" 
                      value={"#{NathanForUsWeb.Endpoint.url()}#{share_url}"}
                      readonly
                      class="flex-1 bg-zinc-700 text-zinc-200 px-2 py-1 rounded font-mono text-xs border border-zinc-600 focus:border-blue-500 focus:outline-none select-all"
                      onclick="this.select(); navigator.clipboard.writeText(this.value); this.classList.add('bg-green-700'); setTimeout(() => this.classList.remove('bg-green-700'), 1000);"
                    />
                    <button
                      onclick="navigator.clipboard.writeText(document.querySelector('input[readonly]').value); this.textContent = 'Copied!'; setTimeout(() => this.textContent = 'Copy', 1000);"
                      class="bg-zinc-600 hover:bg-zinc-500 text-zinc-200 px-2 py-1 rounded text-xs font-mono transition-colors"
                    >
                      Copy
                    </button>
                  </div>
                  <div class="text-zinc-500 text-xs mt-1 font-mono">
                    Share this link to show others your selected frames
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
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

  def animation_container(assigns) do
    first_frame = List.first(assigns.frame_sequence.sequence_frames)

    # Get frame dimensions with fallbacks for nil values
    frame_width = case first_frame do
      nil -> 1920
      frame -> case Map.get(frame, :width) do
        nil -> 1920  # Default to 1920 if nil
        width when is_integer(width) and width > 0 -> width
        _ -> 1920
      end
    end

    frame_height = case first_frame do
      nil -> 1080
      frame -> case Map.get(frame, :height) do
        nil -> 1080  # Default to 1080 if nil
        height when is_integer(height) and height > 0 -> height
        _ -> 1080
      end
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
          data-animation-speed="150"
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
  attr :frame_sequence_version, :integer, default: 0

  def frame_sequence_grid(assigns) do
    # Create a unique key based on frame count and version to force re-render
    assigns =
      assigns
      |> assign(:unique_key, "frames-#{length(assigns.frame_sequence.sequence_frames)}-v#{assigns[:frame_sequence_version] || 0}")
      |> assign(:frame_count, length(assigns.frame_sequence.sequence_frames))

    ~H"""
    <div class="grid grid-cols-3 md:grid-cols-6 lg:grid-cols-8 gap-2" id={@unique_key} phx-update="replace">
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
    <div class="border-2 border-dashed border-zinc-300 rounded-lg overflow-hidden bg-zinc-50 flex flex-col items-center justify-center aspect-video p-3 hover:border-blue-400 hover:bg-blue-50 transition-all cursor-pointer"
         phx-click="expand_sequence_backward"
         title="Click anywhere to add 1 previous frame">
      <div class="text-center mb-3 pointer-events-none">
        <div class="text-3xl text-zinc-400 hover:text-blue-500 mb-2 block">
          −
        </div>
        <div class="text-xs text-zinc-500 font-mono font-bold">EXPAND</div>
        <div class="text-xs text-zinc-400 font-mono">BACK</div>
      </div>
      <div class="w-full" onclick="event.stopPropagation()">
        <form
          id="expand-backward-form"
          phx-submit="expand_sequence_backward_multiple"
          phx-hook="ExpandFrameForm"
          onclick="event.stopPropagation()"
        >
          <input
            name="value"
            type="number"
            min="1"
            max="20"
            placeholder="# frames"
            class="w-full h-8 text-sm text-center border-2 border-blue-300 rounded-md bg-white font-mono font-bold text-blue-600 placeholder-blue-400 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:outline-none"
            title="Enter number of frames to add backward, then press Enter"
            onclick="event.stopPropagation()"
          />
        </form>
        <div class="text-xs text-zinc-400 font-mono text-center mt-1 pointer-events-none">PRESS ENTER</div>
      </div>
    </div>
    """
  end

  @doc """
  Renders expand forward button (adds next frame).
  """
  def expand_forward_button(assigns) do
    ~H"""
    <div class="border-2 border-dashed border-zinc-300 rounded-lg overflow-hidden bg-zinc-50 flex flex-col items-center justify-center aspect-video p-3 hover:border-blue-400 hover:bg-blue-50 transition-all cursor-pointer"
         phx-click="expand_sequence_forward"
         title="Click anywhere to add 1 next frame">
      <div class="text-center mb-3 pointer-events-none">
        <div class="text-3xl text-zinc-400 hover:text-blue-500 mb-2 block">
          +
        </div>
        <div class="text-xs text-zinc-500 font-mono font-bold">EXPAND</div>
        <div class="text-xs text-zinc-400 font-mono">NEXT</div>
      </div>
      <div class="w-full" onclick="event.stopPropagation()">
        <form
          id="expand-forward-form"
          phx-submit="expand_sequence_forward_multiple"
          phx-hook="ExpandFrameForm"
          onclick="event.stopPropagation()"
        >
          <input
            name="value"
            type="number"
            min="1"
            max="20"
            placeholder="# frames"
            class="w-full h-8 text-sm text-center border-2 border-blue-300 rounded-md bg-white font-mono font-bold text-blue-600 placeholder-blue-400 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 focus:outline-none"
            title="Enter number of frames to add forward, then press Enter"
            onclick="event.stopPropagation()"
          />
        </form>
        <div class="text-xs text-zinc-400 font-mono text-center mt-1 pointer-events-none">PRESS ENTER</div>
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
            ✅ <%= length(@selected_frame_indices) %>/<%= @frame_sequence.sequence_info.total_frames %> animating @ 150ms
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


  defp encode_image_data(nil), do: ""
  defp encode_image_data(binary_data) when is_binary(binary_data) do
    # Handle both raw binary data (bytea) and hex-encoded strings
    case binary_data do
      # If it's a hex string starting with \x, decode it first
      "\\x" <> hex_string ->
        case Base.decode16(hex_string, case: :lower) do
          {:ok, decoded_data} -> Base.encode64(decoded_data)
          :error -> ""
        end
      # If it's raw binary data (which it should be from bytea), encode directly
      _ ->
        Base.encode64(binary_data)
    end
  end

  defp get_selected_frames_captions(frame_sequence, selected_frame_indices) do
    # Get selected frames based on indices
    selected_frames =
      selected_frame_indices
      |> Enum.map(&Enum.at(frame_sequence.sequence_frames, &1))
      |> Enum.reject(&is_nil/1)

    if length(selected_frames) > 0 do
      # Collect all unique captions in chronological order
      unique_captions =
        selected_frames
        |> Enum.sort_by(& &1.timestamp_ms)  # Sort by timestamp to maintain order
        |> Enum.flat_map(fn frame ->
          Map.get(frame_sequence.sequence_captions, frame.id, [])
        end)
        |> Enum.uniq()  # Remove duplicates
        |> Enum.reject(&(&1 == "" or is_nil(&1)))  # Remove empty captions

      case unique_captions do
        [] -> "No captions available"
        captions -> Enum.join(captions, " ... ")
      end
    else
      "No frames selected"
    end
  end
end
