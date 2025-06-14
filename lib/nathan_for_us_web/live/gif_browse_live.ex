defmodule NathanForUsWeb.GifBrowseLive do
  @moduledoc """
  Enhanced browse page for ALL generated GIFs with voting and filtering.

  Users can browse GIFs others have made, upvote them, and filter by:
  - Hot (Reddit-style algorithm)
  - Top (most upvoted all time)
  - New (most recent)
  """

  use NathanForUsWeb, :live_view

  alias NathanForUs.Viral

  on_mount {NathanForUsWeb.UserAuth, :mount_current_user}

  def mount(params, session, socket) do
    sort = Map.get(params, "sort", "hot")
    gifs = load_gifs_by_sort(sort)

    # Get session ID for anonymous voting
    session_id = Map.get(session, "live_socket_id")

    # Add caption data to GIFs
    gifs_with_captions = add_caption_data_to_gifs(gifs)

    socket =
      socket
      |> assign(:page_title, "Browse Nathan GIFs")
      |> assign(:gifs, gifs_with_captions)
      |> assign(:loading, false)
      |> assign(:sort, sort)
      |> assign(:session_id, session_id)
      |> assign(:show_register_flash, false)
      |> assign(:show_gif_modal, false)
      |> assign(:modal_gif, nil)
      |> assign(:modal_captions, [])
      |> load_user_votes()

    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    sort = Map.get(params, "sort", "hot")

    if sort != socket.assigns.sort do
      gifs = load_gifs_by_sort(sort)
      gifs_with_captions = add_caption_data_to_gifs(gifs)

      socket =
        socket
        |> assign(:sort, sort)
        |> assign(:loading, true)
        |> assign(:show_gif_modal, false)
        |> assign(:modal_gif, nil)
        |> assign(:modal_captions, [])
        |> assign(:gifs, gifs_with_captions)
        |> assign(:loading, false)
        |> load_user_votes()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("upvote_gif", %{"gif_id" => gif_id}, socket) do
    if socket.assigns.current_user do
      gif_id = String.to_integer(gif_id)
      user_id = socket.assigns.current_user.id

      case Viral.vote_on_gif(gif_id, "up", user_id: user_id) do
        {:ok, _vote} ->
          socket =
            socket
            |> put_flash(:info, "GIF upvoted!")
            |> refresh_gif_votes(gif_id)
            |> load_user_votes()

          {:noreply, socket}

        {:error, _changeset} ->
          socket = put_flash(socket, :error, "Failed to vote on GIF")
          {:noreply, socket}
      end
    else
      socket = assign(socket, :show_register_flash, true)
      {:noreply, socket}
    end
  end

  def handle_event("random_gif", _params, socket) do
    case NathanForUs.Video.get_random_video_sequence(15) do
      {:ok, video_id, start_frame} ->
        # Generate a range of 15 frame indices starting from the random frame
        frame_indices = Enum.to_list(0..14)
        indices_param = Enum.join(frame_indices, ",")

        # Navigate to the video timeline with pre-selected frames
        path =
          ~p"/video-timeline/#{video_id}?random=true&start_frame=#{start_frame}&selected_indices=#{indices_param}"

        socket = redirect(socket, to: path)
        {:noreply, socket}

      {:error, _reason} ->
        socket = put_flash(socket, :error, "No suitable videos found for random GIF generation")
        {:noreply, socket}
    end
  end

  def handle_event("close_register_flash", _params, socket) do
    socket = assign(socket, :show_register_flash, false)
    {:noreply, socket}
  end

  def handle_event("view_gif", %{"gif_id" => gif_id}, socket) do
    # Find the GIF data
    gif_id_int = String.to_integer(gif_id)
    modal_gif = Enum.find(socket.assigns.gifs, fn gif -> gif.id == gif_id_int end)

    if modal_gif && modal_gif.gif && modal_gif.gif.frame_ids do
      # Get captions for this GIF
      captions = NathanForUs.Video.get_gif_captions(modal_gif.gif.frame_ids)
      
      socket = 
        socket
        |> assign(:show_gif_modal, true)
        |> assign(:modal_gif, modal_gif)
        |> assign(:modal_captions, captions)
      
      {:noreply, socket}
    else
      # GIF not found or missing data
      {:noreply, socket}
    end
  end

  def handle_event("close_gif_modal", _params, socket) do
    socket = 
      socket
      |> assign(:show_gif_modal, false)
      |> assign(:modal_gif, nil)
      |> assign(:modal_captions, [])
    
    {:noreply, socket}
  end

  def handle_event("share_gif", %{"gif_id" => gif_id}, socket) do
    # Map to the existing repost_gif functionality
    handle_event("repost_gif", %{"gif_id" => gif_id}, socket)
  end

  def handle_event("repost_gif", %{"gif_id" => browseable_gif_id}, socket) do
    if socket.assigns.current_user do
      # Find the browseable GIF
      browseable_gif_id_int = String.to_integer(browseable_gif_id)
      browseable_gif =
        Enum.find(socket.assigns.gifs, &(&1.id == browseable_gif_id_int))

      if browseable_gif do
        # Create a viral GIF post from this browseable GIF
        attrs = %{
          video_id: browseable_gif.video_id,
          created_by_user_id: socket.assigns.current_user.id,
          gif_id: browseable_gif.gif_id,
          start_frame_index: browseable_gif.start_frame_index,
          end_frame_index: browseable_gif.end_frame_index,
          category: browseable_gif.category,
          frame_data: browseable_gif.frame_data,
          title: browseable_gif.title
        }

        case Viral.create_viral_gif(attrs) do
          {:ok, _viral_gif} ->
            socket = 
              socket
              |> put_flash(:info, "✅ GIF posted to public timeline! Check the NATHAN POST TIMELINE to see it.")
              |> push_navigate(to: ~p"/public-timeline")
            {:noreply, socket}

          {:error, changeset} ->
            error_msg = 
              case changeset.errors do
                [] -> "Unknown error occurred"
                errors -> 
                  errors
                  |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
                  |> Enum.join(", ")
              end
            socket = put_flash(socket, :error, "Failed to post GIF: #{error_msg}")
            {:noreply, socket}
        end
      else
        socket = put_flash(socket, :error, "GIF not found")
        {:noreply, socket}
      end
    else
      # Show register prompt for unauthenticated users
      socket = assign(socket, :show_register_flash, true)
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <!-- Header -->
      <div class="bg-gray-800 border-b border-gray-700 px-6 py-4">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold font-mono">BROWSE GIFS</h1>
            <p class="text-gray-400 text-sm font-mono">
              Discover, upvote, and share the best Nathan moments
            </p>
          </div>

          <div class="flex items-center gap-4">
            <button
              phx-click="random_gif"
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
              title="Generate random GIF from any video"
            >
              🎲 Random GIF
            </button>

            <.link
              navigate={~p"/public-timeline"}
              class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
            >
              NATHAN POST TIMELINE
            </.link>
            <.link
              navigate={~p"/video-timeline"}
              class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg font-mono font-medium transition-colors"
            >
              SEARCH QUOTES
            </.link>
          </div>
        </div>
      </div>
      
    <!-- Custom Register Flash -->
      <%= if @show_register_flash do %>
        <div class="fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1 bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900">
          <p class="flex items-center gap-1.5 text-sm font-semibold leading-6">
            <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
              <path
                fill-rule="evenodd"
                d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zM12 8.25a.75.75 0 01.75.75v3.75a.75.75 0 01-1.5 0V9a.75.75 0 01.75-.75zm0 8.25a.75.75 0 100-1.5.75.75 0 000 1.5z"
                clip-rule="evenodd"
              />
            </svg>
            Account Required
          </p>
          <p class="mt-2 text-sm leading-5">
            Create an account and log in to upvote GIFs.
            <.link navigate={~p"/users/register"} class="font-semibold underline hover:no-underline">
              Click here to register!
            </.link>
          </p>
          <button
            type="button"
            class="group absolute top-1 right-1 p-2"
            phx-click="close_register_flash"
            aria-label="close"
          >
            <svg
              class="h-5 w-5 opacity-40 group-hover:opacity-70"
              fill="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                d="M6 18L18 6M6 6l12 12"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </button>
        </div>
      <% end %>
      
    <!-- Filter Tabs -->
      <div class="bg-gray-800 border-b border-gray-700 px-6 py-3">
        <div class="flex items-center gap-1 max-w-7xl mx-auto">
          <.link
            patch={~p"/browse-gifs?sort=hot"}
            class={[
              "px-4 py-2 rounded font-mono font-medium transition-colors text-sm",
              if(@sort == "hot",
                do: "bg-red-600 text-white",
                else: "text-gray-400 hover:text-white hover:bg-gray-700"
              )
            ]}
          >
            🔥 Hot
          </.link>
          <.link
            patch={~p"/browse-gifs?sort=top"}
            class={[
              "px-4 py-2 rounded font-mono font-medium transition-colors text-sm",
              if(@sort == "top",
                do: "bg-orange-600 text-white",
                else: "text-gray-400 hover:text-white hover:bg-gray-700"
              )
            ]}
          >
            ⭐ Top
          </.link>
          <.link
            patch={~p"/browse-gifs?sort=new"}
            class={[
              "px-4 py-2 rounded font-mono font-medium transition-colors text-sm",
              if(@sort == "new",
                do: "bg-blue-600 text-white",
                else: "text-gray-400 hover:text-white hover:bg-gray-700"
              )
            ]}
          >
            🆕 New
          </.link>
        </div>
      </div>
      
    <!-- GIF Grid -->
      <div class="px-4 py-6">
        <%= if @loading do %>
          <div class="text-center py-12">
            <div class="text-gray-400 font-mono">Loading GIFs...</div>
          </div>
        <% else %>
          <%= if Enum.empty?(@gifs) do %>
            <div class="text-center py-12">
              <div class="text-gray-400 font-mono mb-4">No GIFs created yet</div>
              <.link
                navigate={~p"/video-timeline"}
                class="text-blue-400 hover:text-blue-300 font-mono"
              >
                Create the first GIF →
              </.link>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 max-w-7xl mx-auto">
              <%= for gif <- @gifs do %>
                <div class="bg-gray-800 rounded-lg overflow-hidden border border-gray-700 hover:border-gray-600 transition-colors">
                  <!-- GIF Display -->
                  <div 
                    class="aspect-video bg-gray-700 flex items-center justify-center relative cursor-pointer hover:bg-gray-600 transition-colors"
                    phx-click="view_gif"
                    phx-value-gif_id={gif.id}
                    title="Click to view GIF details"
                  >
                    <%= if gif.gif && gif.gif.gif_data do %>
                      <img
                        src={"data:image/gif;base64,#{NathanForUs.Gif.to_base64(gif.gif)}"}
                        alt={gif.title || "Nathan GIF"}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <div class="text-gray-400 font-mono text-sm text-center p-4">
                        <div>Nathan GIF</div>
                        <div class="text-xs mt-1">
                          Frames {gif.start_frame_index}-{gif.end_frame_index}
                        </div>
                      </div>
                    <% end %>
                    
    <!-- Vote count overlay -->
                    <%= if gif.upvotes_count > 0 do %>
                      <div class="absolute top-2 right-2 bg-black bg-opacity-75 text-white px-2 py-1 rounded text-xs font-mono">
                        ⬆ {gif.upvotes_count}
                      </div>
                    <% end %>
                  </div>
                  
    <!-- GIF Info & Actions -->
                  <div class="p-4">
                    <h3 class="text-white font-mono text-sm mb-2 truncate">
                      {gif.title || "Untitled Nathan GIF"}
                    </h3>

                    <div class="text-gray-400 text-xs font-mono mb-3 leading-relaxed">
                      <%= if gif.caption_preview && gif.caption_preview != "" do %>
                        "{gif.caption_preview}"
                      <% else %>
                        From: {gif.video.title}
                      <% end %>
                    </div>
                    
    <!-- Vote and Action Row -->
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-3">
                        <!-- Upvote Button -->
                        <button
                          phx-click="upvote_gif"
                          phx-value-gif_id={gif.id}
                          class={[
                            "flex items-center gap-1 px-2 py-1 rounded text-xs font-mono transition-colors",
                            if(Map.get(@user_votes, gif.id) == "up",
                              do: "bg-orange-600 text-white",
                              else: "bg-gray-700 text-gray-300 hover:bg-orange-600 hover:text-white"
                            )
                          ]}
                          title="Upvote this GIF"
                        >
                          ⬆ {gif.upvotes_count}
                        </button>
                        
    <!-- Time ago -->
                        <div class="text-gray-500 text-xs font-mono">
                          {format_time_ago(gif.inserted_at)}
                        </div>
                      </div>
                      
    <!-- Repost Button (only for authenticated users) -->
                      <%= if @current_user do %>
                        <button
                          phx-click="repost_gif"
                          phx-value-gif_id={gif.id}
                          class="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded text-xs font-mono transition-colors flex items-center gap-1"
                          title="Share this GIF to the public Nathan timeline"
                        >
                          <span>📤</span> Share
                        </button>
                      <% else %>
                        <button
                          phx-click="repost_gif"
                          phx-value-gif_id={gif.id}
                          class="bg-gray-600 hover:bg-gray-500 text-white px-3 py-1 rounded text-xs font-mono transition-colors flex items-center gap-1"
                          title="Login to share this GIF to the public timeline"
                        >
                          <span>📤</span> Share
                        </button>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
      
      <!-- GIF Modal -->
      <%= if @show_gif_modal and @modal_gif do %>
        <NathanForUsWeb.Components.GifModal.render 
          gif_data={@modal_gif}
          captions={@modal_captions}
          show_share_button={@current_user != nil}
        />
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp load_gifs_by_sort("hot"), do: Viral.get_hot_browseable_gifs()
  defp load_gifs_by_sort("top"), do: Viral.get_top_browseable_gifs()
  defp load_gifs_by_sort("new"), do: Viral.get_new_browseable_gifs()
  defp load_gifs_by_sort(_), do: Viral.get_hot_browseable_gifs()

  defp load_user_votes(socket) do
    user_id = socket.assigns.current_user && socket.assigns.current_user.id
    session_id = socket.assigns.session_id
    gif_ids = Enum.map(socket.assigns.gifs, & &1.id)

    user_votes =
      if user_id do
        Enum.reduce(gif_ids, %{}, fn gif_id, acc ->
          case Viral.get_user_vote(gif_id, user_id: user_id) do
            nil -> acc
            vote_type -> Map.put(acc, gif_id, vote_type)
          end
        end)
      else
        Enum.reduce(gif_ids, %{}, fn gif_id, acc ->
          case Viral.get_user_vote(gif_id, session_id: session_id) do
            nil -> acc
            vote_type -> Map.put(acc, gif_id, vote_type)
          end
        end)
      end

    assign(socket, :user_votes, user_votes)
  end

  defp refresh_gif_votes(socket, gif_id) do
    # Update just the specific GIF's vote count in the current list
    updated_gifs =
      Enum.map(socket.assigns.gifs, fn gif ->
        if gif.id == gif_id do
          # Reload this specific GIF to get updated vote counts
          case Viral.get_recent_browseable_gifs(1)
               |> Enum.find(&(&1.id == gif_id)) do
            nil -> gif
            updated_gif -> updated_gif
          end
        else
          gif
        end
      end)

    assign(socket, :gifs, updated_gifs)
  end

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 2_592_000 -> "#{div(diff, 86400)}d ago"
      true -> "#{div(diff, 2_592_000)}mo ago"
    end
  end

  defp add_caption_data_to_gifs(gifs) do
    Enum.map(gifs, fn gif ->
      caption_text = extract_gif_captions(gif)
      Map.put(gif, :caption_preview, caption_text)
    end)
  end

  defp extract_gif_captions(gif) do
    case gif.frame_data do
      nil ->
        ""

      frame_data_json ->
        try do
          case Jason.decode(frame_data_json) do
            {:ok, %{"frame_ids" => frame_ids}} when is_list(frame_ids) ->
              # Get captions for all frames
              case NathanForUs.Video.get_frames_captions(frame_ids) do
                {:ok, captions_map} ->
                  # Flatten all captions from all frames and get unique ones
                  caption_text =
                    captions_map
                    |> Map.values()
                    |> List.flatten()
                    |> Enum.uniq()
                    |> Enum.join(" ")
                    |> String.slice(0, 250)

                  if String.length(caption_text) == 250 do
                    caption_text <> "..."
                  else
                    caption_text
                  end

                _ ->
                  ""
              end

            _ ->
              ""
          end
        rescue
          _ -> ""
        end
    end
  end
end
