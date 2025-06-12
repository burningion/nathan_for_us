defmodule NathanForUsWeb.Components.VideoSearch.SearchInterface do
  @moduledoc """
  Search interface component for video search functionality.
  
  Provides the main search form, quick suggestions, and search status.
  """
  
  use NathanForUsWeb, :html
  
  @doc """
  Renders the search interface with form, suggestions and status.
  """
  attr :search_term, :string, required: true
  attr :loading, :boolean, required: true
  attr :videos, :list, required: true
  attr :search_mode, :atom, required: true
  attr :selected_video_ids, :list, required: true
  attr :autocomplete_suggestions, :list, default: []
  attr :show_autocomplete, :boolean, default: false
  attr :search_form, :map, default: %{}
  
  def search_interface(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
      <!-- Top row with title and random clip button -->
      <div class="flex items-center justify-between mb-4">
        <div class="text-xs text-blue-600 uppercase tracking-wide">SEARCH INTERFACE</div>
        <.compact_random_clip_button />
      </div>
      
      <.search_form 
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
  Renders the main search form with autocomplete.
  """
  attr :search_term, :string, required: true
  attr :search_form, :map, required: true
  attr :loading, :boolean, required: true
  attr :autocomplete_suggestions, :list, default: []
  attr :show_autocomplete, :boolean, default: false
  
  def search_form(assigns) do
    ~H"""
    <div class="relative mb-4">
      <.form for={@search_form} as={:search} phx-submit="search">
        <div class="flex flex-col sm:flex-row gap-2">
          <div class="relative flex-1">
            <input
              type="text"
              name="search[term]"
              value={@search_term}
              placeholder="Enter search query for spoken dialogue..."
              class="w-full border border-zinc-300 text-zinc-900 px-4 py-3 rounded font-mono focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
              phx-change="autocomplete_search"
              phx-debounce="150"
              autocomplete="off"
            />
            
            <.autocomplete_dropdown 
              :if={@show_autocomplete and length(@autocomplete_suggestions) > 0}
              suggestions={@autocomplete_suggestions}
            />
          </div>
          
          <button
            type="submit"
            disabled={@loading}
            class="bg-blue-600 hover:bg-blue-700 disabled:bg-zinc-400 text-white px-6 py-3 rounded font-mono text-sm transition-colors whitespace-nowrap"
          >
            <%= if @loading, do: "SEARCHING", else: "EXECUTE" %>
          </button>
          <button
            type="button"
            phx-click="toggle_video_modal"
            class="bg-zinc-600 hover:bg-zinc-700 text-white px-4 py-3 rounded font-mono text-sm transition-colors whitespace-nowrap flex items-center gap-2"
          >
            <.icon name="hero-funnel" class="w-4 h-4" />
            FILTER
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @doc """
  Renders the autocomplete dropdown.
  """
  attr :suggestions, :list, required: true

  def autocomplete_dropdown(assigns) do
    ~H"""
    <div 
      class="absolute top-full left-0 right-0 z-50 bg-white border border-zinc-300 border-t-0 rounded-b-lg shadow-lg max-h-48 overflow-y-auto"
      phx-click-away="hide_autocomplete"
    >
      <div class="text-xs text-zinc-500 px-3 py-1 bg-zinc-50 border-b border-zinc-200">
        SUGGESTED PHRASES
      </div>
      <%= for suggestion <- @suggestions do %>
        <button
          type="button"
          phx-click="select_suggestion"
          phx-value-suggestion={suggestion}
          class="w-full text-left px-3 py-2 text-xs text-zinc-900 hover:bg-blue-50 hover:text-blue-700 font-mono border-b border-zinc-100 last:border-b-0 truncate"
          title={suggestion}
        >
          <%= suggestion %>
        </button>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders a compact random clip button for the top-right position.
  """
  def compact_random_clip_button(assigns) do
    ~H"""
    <button
      phx-click="generate_random_clip"
      class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-mono font-medium transition-colors"
      title="Generate a random 5-second Nathan clip"
    >
      Random Clip
    </button>
    """
  end
  
end