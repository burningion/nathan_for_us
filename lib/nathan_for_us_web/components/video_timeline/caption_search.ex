defmodule NathanForUsWeb.Components.VideoTimeline.CaptionSearch do
  @moduledoc """
  Caption search component for video timeline pages.

  Provides caption search functionality segmented to a specific video with autocomplete.
  """

  use NathanForUsWeb, :html

  @doc """
  Renders the caption search interface for a specific video.
  """
  attr :search_term, :string, default: ""
  attr :loading, :boolean, default: false
  attr :video_id, :integer, required: true
  attr :autocomplete_suggestions, :list, default: []
  attr :show_autocomplete, :boolean, default: false
  attr :search_form, :map, default: %{}
  attr :is_filtered, :boolean, default: false
  attr :is_context_view, :boolean, default: false
  attr :context_target_frame, :map, default: nil
  attr :expand_count, :integer, default: 3

  def caption_search(assigns) do
    ~H"""
    <div class="bg-gray-800 border border-gray-600 rounded-lg p-4 mb-4">
      <div class="flex items-center justify-between mb-3">
        <div class="text-xs text-blue-400 uppercase tracking-wide font-mono">
          <%= if @is_context_view do %>
            CONTEXT VIEW
          <% else %>
            CAPTION SEARCH
          <% end %>
        </div>
        <div class="flex items-center gap-2">
          <%= cond do %>
            <% @is_context_view -> %>
              <button
                phx-click="back_to_search_results"
                class="text-xs text-green-400 hover:text-green-300 font-mono underline"
              >
                ← Back to Results
              </button>
              <button
                phx-click="clear_caption_filter"
                class="text-xs text-yellow-400 hover:text-yellow-300 font-mono underline"
              >
                Clear All
              </button>
            <% @is_filtered -> %>
              <button
                phx-click="clear_caption_filter"
                class="text-xs text-yellow-400 hover:text-yellow-300 font-mono underline"
              >
                Clear Filter
              </button>
            <% true -> %>
              <div class="text-xs text-gray-400 font-mono">Video-specific search</div>
          <% end %>
        </div>
      </div>

      <%= if @is_context_view and @context_target_frame do %>
        <div class="mb-3 p-2 bg-gray-700 rounded text-xs text-gray-300 font-mono">
          Showing context around frame #{@context_target_frame.frame_number}
          <span class="text-blue-400">({format_timestamp(@context_target_frame.timestamp_ms)})</span>
        </div>
      <% end %>

      <.caption_search_form
        search_term={@search_term}
        search_form={@search_form}
        loading={@loading}
        autocomplete_suggestions={@autocomplete_suggestions}
        show_autocomplete={@show_autocomplete}
      />
    </div>
    """
  end

  @doc """
  Renders the caption search form with autocomplete.
  """
  attr :search_term, :string, required: true
  attr :search_form, :map, required: true
  attr :loading, :boolean, required: true
  attr :autocomplete_suggestions, :list, default: []
  attr :show_autocomplete, :boolean, default: false

  def caption_search_form(assigns) do
    ~H"""
    <div class="relative">
      <.form for={@search_form} as={:caption_search} phx-submit="caption_search">
        <div class="flex gap-2">
          <div class="relative flex-1">
            <input
              type="text"
              name="caption_search[term]"
              value={@search_term}
              placeholder="Search captions in this video..."
              class="w-full bg-gray-700 border border-gray-600 text-white px-4 py-3 rounded font-mono placeholder-gray-400 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
              phx-change="caption_autocomplete"
              phx-debounce="150"
              autocomplete="off"
            />

            <.caption_autocomplete_dropdown
              :if={@show_autocomplete and length(@autocomplete_suggestions) > 0}
              suggestions={@autocomplete_suggestions}
            />
          </div>

          <button
            type="submit"
            disabled={@loading}
            class="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white px-6 py-3 rounded font-mono text-sm transition-colors whitespace-nowrap"
          >
            {if @loading, do: "SEARCHING", else: "SEARCH"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @doc """
  Renders the caption autocomplete dropdown.
  """
  attr :suggestions, :list, required: true

  def caption_autocomplete_dropdown(assigns) do
    ~H"""
    <div
      class="absolute top-full left-0 right-0 z-50 bg-gray-700 border border-gray-600 border-t-0 rounded-b-lg shadow-lg max-h-48 overflow-y-auto"
      phx-click-away="hide_caption_autocomplete"
    >
      <div class="text-xs text-gray-400 px-3 py-1 bg-gray-800 border-b border-gray-600 font-mono">
        SUGGESTED CAPTIONS
      </div>
      <%= for suggestion <- @suggestions do %>
        <button
          type="button"
          phx-click="select_caption_suggestion"
          phx-value-suggestion={suggestion}
          class="w-full text-left px-3 py-2 text-sm text-gray-200 hover:bg-gray-600 hover:text-blue-300 font-mono border-b border-gray-600 last:border-b-0 truncate"
          title={suggestion}
        >
          {suggestion}
        </button>
      <% end %>
    </div>
    """
  end

  # Helper function to format timestamp
  defp format_timestamp(nil), do: "0:00"

  defp format_timestamp(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
end
