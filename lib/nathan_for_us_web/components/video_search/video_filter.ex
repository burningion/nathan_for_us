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
      <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto" phx-click-away="toggle_video_modal">
        <div class="p-6">
          <.modal_header />
          
          <.video_list 
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
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-xl font-bold text-zinc-900 font-mono">SELECT VIDEOS TO SEARCH</h2>
      <button
        phx-click="toggle_video_modal"
        class="text-zinc-500 hover:text-zinc-700 transition-colors"
      >
        <.icon name="hero-x-mark" class="w-6 h-6" />
      </button>
    </div>
    """
  end
  
  @doc """
  Renders the list of videos with selection checkboxes.
  """
  attr :videos, :list, required: true
  attr :selected_video_ids, :list, required: true
  
  def video_list(assigns) do
    ~H"""
    <div class="space-y-3 mb-6">
      <%= for video <- @videos do %>
        <.video_item 
          video={video}
          selected={video.id in @selected_video_ids}
        />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders an individual video item with checkbox.
  """
  attr :video, :map, required: true
  attr :selected, :boolean, required: true
  
  def video_item(assigns) do
    ~H"""
    <div class={[
      "p-3 border rounded cursor-pointer transition-colors font-mono text-sm",
      if(@selected, do: "border-blue-500 bg-blue-50 text-blue-900", else: "border-zinc-300 hover:border-zinc-400 text-zinc-700")
    ]}
    phx-click="toggle_video_selection"
    phx-value-video_id={@video.id}>
      <div class="flex items-center gap-3">
        <.video_checkbox selected={@selected} />
        <.video_details video={@video} />
      </div>
    </div>
    """
  end
  
  @doc """
  Renders the selection checkbox.
  """
  attr :selected, :boolean, required: true
  
  def video_checkbox(assigns) do
    ~H"""
    <div class={[
      "w-5 h-5 border-2 rounded flex items-center justify-center",
      if(@selected, do: "border-blue-500 bg-blue-500", else: "border-zinc-300")
    ]}>
      <%= if @selected do %>
        <.icon name="hero-check" class="w-3 h-3 text-white" />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders video details (title, frame count, duration).
  """
  attr :video, :map, required: true
  
  def video_details(assigns) do
    ~H"""
    <div class="flex-1">
      <div class="font-bold truncate"><%= @video.title %></div>
      <div class="text-xs text-zinc-500 mt-1">
        <%= if @video.frame_count, do: "#{@video.frame_count} frames", else: "Processing..." %> | 
        <%= if @video.duration_ms, do: format_timestamp(@video.duration_ms), else: "Unknown duration" %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders modal action buttons.
  """
  attr :selected_count, :integer, required: true
  
  def modal_actions(assigns) do
    ~H"""
    <div class="flex gap-3 justify-end">
      <button
        phx-click="toggle_video_modal"
        class="px-4 py-2 border border-zinc-300 text-zinc-700 rounded font-mono text-sm hover:bg-zinc-50 transition-colors"
      >
        CANCEL
      </button>
      <button
        phx-click="apply_video_filter"
        class="px-4 py-2 bg-blue-600 text-white rounded font-mono text-sm hover:bg-blue-700 transition-colors"
      >
        APPLY FILTER (<%= @selected_count %> selected)
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
end