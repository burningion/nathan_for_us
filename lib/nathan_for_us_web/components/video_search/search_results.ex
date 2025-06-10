defmodule NathanForUsWeb.Components.VideoSearch.SearchResults do
  @moduledoc """
  Search results components for video search functionality.
  
  Handles displaying search results in a mosaic grid layout.
  """
  
  use NathanForUsWeb, :html
  
  @doc """
  Renders search results or empty state.
  """
  attr :search_results, :list, required: true
  attr :search_term, :string, required: true
  
  def search_results(assigns) do
    ~H"""
    <%= if length(@search_results) > 0 do %>
      <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
        <div class="text-xs text-blue-600 uppercase mb-4 tracking-wide">
          SEARCH RESULTS - GROUPED BY VIDEO
        </div>
        <div class="space-y-4">
          <%= for video_result <- @search_results do %>
            <.video_group video_result={video_result} />
          <% end %>
        </div>
      </div>
    <% else %>
      <.empty_state :if={@search_term != ""} search_term={@search_term} />
    <% end %>
    """
  end
  
  @doc """
  Renders a video group with expandable frame tiles.
  """
  attr :video_result, :map, required: true
  
  def video_group(assigns) do
    ~H"""
    <div class="border border-zinc-200 rounded-lg overflow-hidden">
      <!-- Video Header - Always Visible -->
      <div 
        class="bg-zinc-50 p-3 cursor-pointer hover:bg-zinc-100 transition-colors border-b border-zinc-200"
        phx-click="toggle_video_expansion"
        phx-value-video_id={@video_result.video_id}
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <div class="text-blue-600">
              <%= if @video_result.expanded do %>
                <.icon name="hero-chevron-down" class="w-5 h-5" />
              <% else %>
                <.icon name="hero-chevron-right" class="w-5 h-5" />
              <% end %>
            </div>
            <div>
              <h3 class="font-medium text-zinc-900 text-sm">
                <%= @video_result.video_title %>
              </h3>
              <p class="text-xs text-zinc-500 font-mono">
                <%= @video_result.frame_count %> matching frame<%= if @video_result.frame_count != 1, do: "s" %>
              </p>
            </div>
          </div>
          
          <div class="flex items-center gap-3">
            <!-- Timeline Browser Button -->
            <.link 
              navigate={~p"/video-timeline/#{@video_result.video_id}"}
              class="inline-flex items-center gap-1 px-3 py-1 text-xs font-mono text-blue-600 hover:text-blue-700 bg-blue-50 hover:bg-blue-100 rounded-full transition-colors"
              title="Browse entire video on timeline"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
              </svg>
              Timeline
            </.link>
            
            <div class="text-xs text-zinc-400 font-mono">
              <%= if @video_result.expanded, do: "COLLAPSE", else: "EXPAND" %>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Frames Grid - Only Visible When Expanded -->
      <%= if @video_result.expanded do %>
        <div class="p-4 bg-white">
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <%= for frame <- @video_result.frames do %>
              <.frame_tile frame={frame} />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders an individual frame tile for mosaic view.
  """
  attr :frame, :map, required: true
  
  def frame_tile(assigns) do
    ~H"""
    <div 
      class="border border-zinc-300 rounded-lg overflow-hidden hover:shadow-md transition-shadow bg-white cursor-pointer hover:border-blue-500"
      phx-click="show_frame_sequence"
      phx-value-frame_id={@frame.id}
    >
      <.frame_tile_image frame={@frame} />
      <.frame_tile_info frame={@frame} />
    </div>
    """
  end
  
  @doc """
  Renders the frame image within a tile.
  """
  attr :frame, :map, required: true
  
  def frame_tile_image(assigns) do
    ~H"""
    <div class="aspect-video bg-zinc-100 relative">
      <%= if Map.get(@frame, :image_data) do %>
        <img
          id={"tile-frame-#{@frame.id}"}
          src={"data:image/jpeg;base64,#{encode_image_data(@frame.image_data)}"}
          alt={"Frame at " <> format_timestamp(@frame.timestamp_ms)}
          class="w-full h-full object-cover"
        />
      <% else %>
        <div class="w-full h-full flex items-center justify-center text-zinc-400">
          <.icon name="hero-photo" class="w-8 h-8" />
        </div>
      <% end %>
      
      <!-- Timestamp overlay -->
      <div class="absolute bottom-1 right-1 bg-black/70 text-white px-1 py-0.5 rounded text-xs font-mono">
        <%= format_timestamp(@frame.timestamp_ms) %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders frame information within a tile.
  """
  attr :frame, :map, required: true
  
  def frame_tile_info(assigns) do
    ~H"""
    <div class="p-2">
      <%= if Map.get(@frame, :video_title) do %>
        <div class="text-blue-600 text-xs font-mono font-bold mb-1 truncate">
          <%= String.slice(@frame.video_title, 0..40) %><%= if String.length(@frame.video_title) > 40, do: "..." %>
        </div>
      <% end %>
      
      <div class="flex items-center justify-between mb-2">
        <span class="text-zinc-500 text-xs font-mono">FRAME #<%= @frame.frame_number %></span>
        <%= if @frame.file_size do %>
          <span class="text-zinc-400 text-xs font-mono"><%= format_file_size(@frame.file_size) %></span>
        <% end %>
      </div>
      
      <%= if Map.get(@frame, :caption_texts) do %>
        <div class="border-l-2 border-blue-600 pl-2">
          <div class="text-zinc-800 text-xs leading-relaxed line-clamp-3">
            "<%= @frame.caption_texts %>"
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders empty state when no results found.
  """
  attr :search_term, :string, required: true
  
  def empty_state(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-8 text-center shadow-sm">
      <div class="text-blue-600 text-lg mb-2 font-mono">
        NO MATCHES FOUND
      </div>
      <p class="text-zinc-600 text-sm mb-4">
        No video frames found containing "<%= @search_term %>"
      </p>
      <p class="text-zinc-500 text-xs font-mono">
        Try different keywords or check the quick queries above
      </p>
    </div>
    """
  end
  
  @doc """
  Renders loading state.
  """
  attr :search_term, :string, required: true
  
  def loading_state(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-8 text-center shadow-sm">
      <div class="text-blue-600 text-lg mb-2 font-mono">
        PROCESSING QUERY
      </div>
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
      <p class="text-zinc-600 text-sm font-mono">
        Scanning video database for: "<%= @search_term %>"
      </p>
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
end