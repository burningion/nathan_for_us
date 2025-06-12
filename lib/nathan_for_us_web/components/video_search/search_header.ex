defmodule NathanForUsWeb.Components.VideoSearch.SearchHeader do
  @moduledoc """
  Search header component displaying the main title and status information.
  """

  use NathanForUsWeb, :html

  @doc """
  Renders the search header with title and status display.
  """
  attr :search_term, :string, required: true
  attr :results_count, :integer, required: true

  def search_header(assigns) do
    ~H"""
    <div class="mb-8 border-b border-zinc-300 pb-6">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <.title_section />
        <.status_panel
          search_term={@search_term}
          results_count={@results_count}
        />
      </div>
    </div>
    """
  end

  @doc """
  Renders the title and description section.
  """
  def title_section(assigns) do
    ~H"""
    <div>
      <h1 class="text-xl md:text-2xl font-bold text-blue-600 mb-1">Nathan Fielder Video Search</h1>
    </div>
    """
  end

  @doc """
  Renders the status panel showing current search state.
  """
  attr :search_term, :string, required: true
  attr :results_count, :integer, required: true

  def status_panel(assigns) do
    ~H"""
    <div class="text-left md:text-right text-xs text-zinc-500 space-y-1">
      <div>STATUS: <%= if @search_term != "", do: "SEARCHING", else: "READY" %></div>
      <div>RESULTS: <%= @results_count %></div>
      <div class="truncate max-w-xs">QUERY: "<%= @search_term %>"</div>
    </div>
    """
  end
end
