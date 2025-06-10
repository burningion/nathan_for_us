defmodule NathanForUsWeb.Components.VideoSearch.VideoFilter do
  @moduledoc """
  Video filter modal component for selecting which videos to search within.
  """
  
  use NathanForUsWeb, :html
  
  @doc """
  Renders the video filter modal.
  """
  attr :videos, :list, required: true
  attr :selected_video_ids, :list, required: true
  
  def video_filter_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" phx-click="toggle_video_modal">
      <div class="bg-white rounded-lg shadow-xl max-w-3xl w-full mx-4" phx-click-away="toggle_video_modal">
        <div class="p-4">
          <.modal_header />
          
          <.compact_video_selector 
            videos={@videos}
            selected_video_ids={@selected_video_ids}
          />
          
          <.modal_actions selected_count={length(@selected_video_ids)} />
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders the modal header.
  """
  def modal_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-3">
      <h3 class="text-lg font-semibold text-zinc-900">Select Videos</h3>
      <button
        phx-click="toggle_video_modal"
        class="text-zinc-400 hover:text-zinc-600 transition-colors"
      >
        <.icon name="hero-x-mark" class="w-5 h-5" />
      </button>
    </div>
    """
  end
  
  @doc """
  Renders a compact video selector with chips and dropdown.
  """
  attr :videos, :list, required: true
  attr :selected_video_ids, :list, required: true
  
  def compact_video_selector(assigns) do
    assigns = assign(assigns, :selected_videos, Enum.filter(assigns.videos, &(&1.id in assigns.selected_video_ids)))
    
    ~H"""
    <div class="mb-4">
      <!-- Top row: Selected count and quick actions -->
      <div class="flex items-center justify-between mb-3">
        <div class="text-sm text-zinc-700 font-medium">
          Selected Videos (<%= length(@selected_videos) %>)
        </div>
        <div class="flex gap-2">
          <button
            phx-click="select_all_videos"
            class="text-xs px-3 py-1 bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition-colors"
          >
            Select All
          </button>
          <button
            phx-click="clear_video_selection"
            class="text-xs px-3 py-1 bg-zinc-100 text-zinc-700 rounded hover:bg-zinc-200 transition-colors"
          >
            Clear All
          </button>
        </div>
      </div>
      
      <!-- Selected videos as chips -->
      <div class="mb-4">
        <div class="flex flex-wrap gap-2 min-h-[32px] p-3 bg-zinc-50 rounded border">
          <%= if length(@selected_videos) == 0 do %>
            <span class="text-sm text-zinc-400 italic">No videos selected</span>
          <% else %>
            <%= for video <- @selected_videos do %>
              <.video_chip video={video} />
            <% end %>
          <% end %>
        </div>
      </div>
      
      <!-- Available videos dropdown-style list -->
      <div>
        <div class="text-xs text-zinc-500 mb-1">Available Videos:</div>
        <div class="border border-zinc-200 rounded max-h-64 overflow-y-auto">
          <%= for video <- @videos do %>
            <.compact_video_item 
              video={video}
              selected={video.id in @selected_video_ids}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders a compact video item for the dropdown list.
  """
  attr :video, :map, required: true
  attr :selected, :boolean, required: true
  
  def compact_video_item(assigns) do
    ~H"""
    <div class={[
      "px-4 py-3 border-b border-zinc-100 last:border-b-0 cursor-pointer transition-colors text-sm",
      if(@selected, do: "bg-blue-50 text-blue-900", else: "hover:bg-zinc-50 text-zinc-700")
    ]}
    phx-click="toggle_video_selection"
    phx-value-video_id={@video.id}>
      <div class="flex items-center gap-3">
        <div class={[
          "w-4 h-4 border rounded flex items-center justify-center flex-shrink-0",
          if(@selected, do: "border-blue-500 bg-blue-500", else: "border-zinc-300")
        ]}>
          <%= if @selected do %>
            <.icon name="hero-check" class="w-2.5 h-2.5 text-white" />
          <% end %>
        </div>
        <div class="flex-1 min-w-0">
          <div class="font-medium text-sm mb-1"><%= @video.title %></div>
          <div class="text-xs text-zinc-500 flex gap-3">
            <span><%= format_frame_count(@video.frame_count) %></span>
            <span><%= format_timestamp(@video.duration_ms) %></span>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders a selected video as a removable chip.
  """
  attr :video, :map, required: true
  
  def video_chip(assigns) do
    ~H"""
    <div class="inline-flex items-center gap-2 px-3 py-2 bg-blue-100 text-blue-800 rounded text-sm max-w-md">
      <span class="truncate"><%= truncate_title(@video.title, 50) %></span>
      <button
        phx-click="toggle_video_selection"
        phx-value-video_id={@video.id}
        class="flex-shrink-0 hover:text-blue-900 transition-colors"
      >
        <.icon name="hero-x-mark" class="w-4 h-4" />
      </button>
    </div>
    """
  end
  
  @doc """
  Renders modal action buttons.
  """
  attr :selected_count, :integer, required: true
  
  def modal_actions(assigns) do
    ~H"""
    <div class="flex gap-2 justify-end pt-3 border-t border-zinc-200">
      <button
        phx-click="toggle_video_modal"
        class="px-3 py-1.5 border border-zinc-300 text-zinc-700 rounded text-sm hover:bg-zinc-50 transition-colors"
      >
        Cancel
      </button>
      <button
        phx-click="apply_video_filter"
        class={[
          "px-3 py-1.5 rounded text-sm transition-colors",
          if(@selected_count > 0, 
            do: "bg-blue-600 text-white hover:bg-blue-700", 
            else: "bg-zinc-200 text-zinc-500 cursor-not-allowed")
        ]}
        disabled={@selected_count == 0}
      >
        Apply (<%= @selected_count %>)
      </button>
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
  
  defp format_frame_count(count) when is_integer(count), do: "#{count} frames"
  defp format_frame_count(_), do: "Processing..."
  
  defp truncate_title(title, max_length) when byte_size(title) > max_length do
    String.slice(title, 0..(max_length - 3)) <> "..."
  end
  defp truncate_title(title, _max_length), do: title
end