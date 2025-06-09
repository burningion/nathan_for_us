defmodule NathanForUsWeb.VideoSearchLiveWithVideoSelector do
  @moduledoc """
  BACKUP: Original video-specific search implementation with video selector.
  
  This module contains the original video search functionality that allows
  users to select a specific video and search within that video only.
  
  This code is preserved for future "episode search" functionality where
  users might want to search within specific videos/episodes.
  
  Key features:
  - Video selector dropdown
  - Search within selected video only
  - Video-specific search results
  - Frame-caption associations for selected video
  
  To restore this functionality:
  1. Copy this code back to video_search_live.ex
  2. Update router to use this module
  3. Test video selector functionality
  """
  
  use NathanForUsWeb, :live_view
  
  alias NathanForUs.Video

  on_mount {__MODULE__, :assign_meta_tags}

  def on_mount(:assign_meta_tags, _params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Nathan Appearance Video Search")
      |> assign(:page_description, "search a quote and find the frame(s) in which nathan said it in an interview")
    
    {:cont, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    videos = Video.list_videos()
    selected_video_id = case videos do
      [first_video | _] -> first_video.id
      [] -> nil
    end

    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:loading, false)
      |> assign(:videos, videos)
      |> assign(:selected_video_id, selected_video_id)

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"term" => term, "video_id" => video_id}}, socket) when term != "" do
    video_id = if video_id == "", do: socket.assigns.selected_video_id, else: String.to_integer(video_id)
    send(self(), {:perform_search, term, video_id})
    
    socket =
      socket
      |> assign(:search_term, term)
      |> assign(:selected_video_id, video_id)
      |> assign(:loading, true)
      |> assign(:search_results, [])

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => %{"term" => ""}}, socket) do
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:loading, false)

    {:noreply, socket}
  end

  def handle_event("search", %{"search[term]" => term}, socket) when term != "" do
    send(self(), {:perform_search, term, socket.assigns.selected_video_id})
    
    socket =
      socket
      |> assign(:search_term, term)
      |> assign(:loading, true)
      |> assign(:search_results, [])

    {:noreply, socket}
  end

  def handle_event("video_select", %{"video_id" => video_id}, socket) do
    video_id = String.to_integer(video_id)
    
    socket =
      socket
      |> assign(:selected_video_id, video_id)
      |> assign(:search_results, [])
      |> assign(:search_term, "")

    {:noreply, socket}
  end

  def handle_event("search", %{"search[term]" => ""}, socket) do
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:perform_search, term, video_id}, socket) do
    results = Video.search_frames_by_text_simple(term, video_id)
    
    socket =
      socket
      |> assign(:search_results, results)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 text-zinc-900 p-4 md:p-6 font-mono">
      <div class="max-w-5xl mx-auto">
        <.search_header search_term={@search_term} results_count={length(@search_results)} />
        
        <div class="space-y-4">
          <.video_selector 
            videos={@videos}
            selected_video_id={@selected_video_id}
          />
          
          <.search_interface 
            search_term={@search_term} 
            loading={@loading}
            selected_video_id={@selected_video_id}
          />
          
          <.search_results 
            :if={!@loading}
            search_results={@search_results}
            search_term={@search_term}
          />
          
          <.loading_state :if={@loading} />
        </div>
      </div>
    </div>
    """
  end

  # Video selector component
  defp video_selector(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
      <div class="text-xs text-blue-600 uppercase mb-4 tracking-wide">VIDEO SELECTION</div>
      
      <div class="space-y-3">
        <%= for video <- @videos do %>
          <div class={[
            "p-3 border rounded cursor-pointer transition-colors font-mono text-sm",
            if(@selected_video_id == video.id, do: "border-blue-500 bg-blue-50 text-blue-900", else: "border-zinc-300 hover:border-zinc-400 text-zinc-700")
          ]}
          phx-click="video_select"
          phx-value-video_id={video.id}>
            <div class="font-bold truncate"><%= video.title %></div>
            <div class="text-xs text-zinc-500 mt-1">
              <%= if video.frame_count, do: "#{video.frame_count} frames", else: "Processing..." %> | 
              <%= if video.duration_ms, do: format_timestamp(video.duration_ms), else: "Unknown duration" %>
            </div>
          </div>
        <% end %>
        
        <%= if length(@videos) == 0 do %>
          <div class="text-zinc-500 text-sm italic">No videos available</div>
        <% end %>
      </div>
    </div>
    """
  end

  # Search header component (captain's log style)
  defp search_header(assigns) do
    ~H"""
    <div class="mb-8 border-b border-zinc-300 pb-6">
      <div class="mb-4">
        <h1 class="text-2xl md:text-4xl font-bold text-zinc-900 font-mono tracking-tight">
          NATHAN FIELDER VIDEO SEARCH
        </h1>
        <div class="text-sm md:text-base text-zinc-600 mt-2 font-mono">
          SEARCH DATABASE FOR SPOKEN DIALOGUE ACROSS INTERVIEWS
        </div>
      </div>
      
      <%= if @search_term != "" do %>
        <div class="bg-blue-50 border border-blue-200 rounded p-3">
          <div class="text-xs text-blue-600 uppercase mb-1 tracking-wide">SEARCH RESULTS</div>
          <div class="font-mono text-sm text-blue-900">
            Query: "<span class="font-bold"><%= @search_term %></span>" | 
            Results: <span class="font-bold"><%= @results_count %></span> frames
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Search interface component
  defp search_interface(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
      <div class="text-xs text-blue-600 uppercase mb-4 tracking-wide">SEARCH INTERFACE</div>
      
      <.form for={%{}} as={:search} phx-submit="search" class="mb-4">
        <input type="hidden" name="search[video_id]" value={@selected_video_id} />
        <div class="flex flex-col sm:flex-row gap-2">
          <input
            type="text"
            name="search[term]"
            value={@search_term}
            placeholder="Enter search query for spoken dialogue..."
            class="flex-1 border border-zinc-300 text-zinc-900 px-4 py-3 rounded font-mono focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
            disabled={is_nil(@selected_video_id)}
          />
          <button
            type="submit"
            disabled={@loading or is_nil(@selected_video_id)}
            class="bg-blue-600 hover:bg-blue-700 disabled:bg-zinc-400 text-white px-6 py-3 rounded font-mono text-sm transition-colors whitespace-nowrap"
          >
            <%= if @loading, do: "SEARCHING", else: "EXECUTE" %>
          </button>
        </div>
      </.form>
      
      <!-- Quick search suggestions -->
      <div class="border-t border-zinc-200 pt-4">
        <div class="text-xs text-zinc-500 uppercase mb-2">QUICK QUERIES</div>
        <div class="flex flex-wrap gap-2">
          <.suggestion_button query="train" disabled={is_nil(@selected_video_id)} />
          <.suggestion_button query="choo choo" disabled={is_nil(@selected_video_id)} />
          <.suggestion_button query="sound" disabled={is_nil(@selected_video_id)} />
          <.suggestion_button query="business" disabled={is_nil(@selected_video_id)} />
        </div>
      </div>
      
      <%= if is_nil(@selected_video_id) do %>
        <div class="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded text-yellow-800 text-sm">
          Please select a video above to begin searching.
        </div>
      <% end %>
    </div>
    """
  end

  # Suggestion button component
  defp suggestion_button(assigns) do
    ~H"""
    <button
      phx-click="search"
      phx-value-search[term]={@query}
      disabled={@disabled}
      class="px-3 py-1 text-xs border border-zinc-300 rounded hover:bg-zinc-100 disabled:opacity-50 disabled:cursor-not-allowed font-mono"
    >
      "<%= @query %>"
    </button>
    """
  end

  # Search results component
  defp search_results(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= if length(@search_results) > 0 do %>
        <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
          <div class="text-xs text-blue-600 uppercase mb-4 tracking-wide">
            SEARCH RESULTS (<%= length(@search_results) %>)
          </div>
          
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for result <- @search_results do %>
              <div class="border border-zinc-200 rounded-lg overflow-hidden bg-zinc-50 hover:bg-zinc-100 transition-colors">
                <!-- Frame Image -->
                <div class="aspect-video bg-zinc-200 flex items-center justify-center">
                  <%= if result.image_data do %>
                    <%= case result.image_data do %>
                      <% "\\x" <> hex_data -> %>
                        <img 
                          src={"data:image/jpeg;base64,#{Base.encode64(:binary.decode_hex(String.slice(hex_data, 2..-1//1)))}"} 
                          alt={"Frame at #{format_timestamp(result.timestamp_ms)}"}
                          class="w-full h-full object-cover"
                        />
                      <% binary_data -> %>
                        <img 
                          src={"data:image/jpeg;base64,#{Base.encode64(binary_data)}"} 
                          alt={"Frame at #{format_timestamp(result.timestamp_ms)}"}
                          class="w-full h-full object-cover"
                        />
                    <% end %>
                  <% else %>
                    <div class="text-zinc-400 text-sm">No image</div>
                  <% end %>
                </div>
                
                <!-- Frame Info -->
                <div class="p-3">
                  <div class="text-xs text-zinc-500 mb-1 font-mono">
                    FRAME #<%= result.frame_number %> | <%= format_timestamp(result.timestamp_ms) %>
                  </div>
                  
                  <!-- Caption Text -->
                  <%= if result.caption_text do %>
                    <div class="text-sm text-zinc-700 font-mono leading-relaxed">
                      <%= highlight_search_term(result.caption_text, @search_term) %>
                    </div>
                  <% else %>
                    <div class="text-xs text-zinc-400 italic">No caption available</div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <%= if @search_term != "" do %>
          <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
            <div class="text-center text-zinc-500">
              <div class="text-sm font-mono">No results found for "<%= @search_term %>"</div>
              <div class="text-xs mt-1">Try a different search term or check spelling</div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Loading state component
  defp loading_state(assigns) do
    ~H"""
    <div class="bg-white border border-zinc-300 rounded-lg p-4 md:p-6 shadow-sm">
      <div class="text-center text-zinc-500">
        <div class="text-sm font-mono animate-pulse">SEARCHING DATABASE...</div>
        <div class="text-xs mt-1">Processing query across frames and captions</div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_timestamp(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end
  
  defp format_timestamp(_), do: "00:00"

  defp highlight_search_term(text, search_term) when is_binary(text) and is_binary(search_term) do
    case String.contains?(String.downcase(text), String.downcase(search_term)) do
      true ->
        # Simple highlighting - can be improved with regex for case-insensitive
        highlighted = String.replace(text, search_term, "<mark class=\"bg-yellow-200 px-1 rounded\">#{search_term}</mark>", global: true)
        {:safe, highlighted}
      false ->
        text
    end
  end
  
  defp highlight_search_term(text, _), do: text
end