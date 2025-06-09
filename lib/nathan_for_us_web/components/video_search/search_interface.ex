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
  
  def search_interface(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
      <div class="text-xs text-blue-600 uppercase mb-4 tracking-wide">SEARCH INTERFACE</div>
      
      <.search_form search_term={@search_term} loading={@loading} />
      
      <.quick_suggestions />
      
      <.search_status 
        search_mode={@search_mode}
        videos={@videos}
        selected_video_ids={@selected_video_ids}
      />
    </div>
    """
  end
  
  @doc """
  Renders the main search form.
  """
  attr :search_term, :string, required: true
  attr :loading, :boolean, required: true
  
  def search_form(assigns) do
    ~H"""
    <.form for={%{}} as={:search} phx-submit="search" class="mb-4">
      <div class="flex flex-col sm:flex-row gap-2">
        <input
          type="text"
          name="search[term]"
          value={@search_term}
          placeholder="Enter search query for spoken dialogue..."
          class="flex-1 border border-zinc-300 text-zinc-900 px-4 py-3 rounded font-mono focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
        />
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
    """
  end
  
  @doc """
  Renders quick search suggestions.
  """
  def quick_suggestions(assigns) do
    ~H"""
    <div class="border-t border-zinc-200 pt-4">
      <div class="text-xs text-zinc-500 uppercase mb-2">QUICK QUERIES</div>
      <div class="flex flex-wrap gap-2">
        <.suggestion_button query="nathan" />
        <.suggestion_button query="business" />
        <.suggestion_button query="train" />
        <.suggestion_button query="conan" />
        <.suggestion_button query="rehearsal" />
      </div>
    </div>
    """
  end
  
  @doc """
  Renders a suggestion button.
  """
  attr :query, :string, required: true
  
  def suggestion_button(assigns) do
    ~H"""
    <button
      phx-click="search"
      phx-value-search[term]={@query}
      class="px-3 py-1 bg-zinc-100 hover:bg-zinc-200 text-zinc-700 border border-zinc-300 rounded text-xs font-mono transition-colors"
    >
      "<%= @query %>"
    </button>
    """
  end
  
  @doc """
  Renders the search status panel.
  """
  attr :search_mode, :atom, required: true
  attr :videos, :list, required: true
  attr :selected_video_ids, :list, required: true
  
  def search_status(assigns) do
    ~H"""
    <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded text-blue-800 text-sm font-mono">
      <div class="text-xs text-blue-600 uppercase mb-1">SEARCH STATUS</div>
      <%= if @search_mode == :global do %>
        Searching across all <%= length(@videos) %> videos
      <% else %>
        <div class="flex items-center justify-between">
          <div>
            Filtering <%= length(@selected_video_ids) %> of <%= length(@videos) %> videos
          </div>
          <button
            phx-click="clear_video_filter"
            class="text-xs bg-blue-600 hover:bg-blue-700 text-white px-2 py-1 rounded transition-colors"
          >
            CLEAR FILTER
          </button>
        </div>
      <% end %>
    </div>
    """
  end
end