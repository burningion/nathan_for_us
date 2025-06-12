defmodule NathanForUsWeb.VideoSearchLive do
  @moduledoc """
  LiveView for searching video frames by text content in captions.

  Allows users to search for text across all video captions and displays
  matching frames as images loaded directly from the database.
  """

  use NathanForUsWeb, :live_view

  alias NathanForUs.Video
  alias NathanForUs.Video.Search
  alias NathanForUsWeb.Components.VideoSearch.{
    SearchHeader,
    SearchInterface,
    SearchResults,
    VideoFilter,
    FrameSequence
  }

  on_mount {__MODULE__, :assign_meta_tags}

  def on_mount(:assign_meta_tags, _params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Nathan Search")
      |> assign(:page_description, "search a quote and find the frame(s) in which nathan said it in an interview")

    {:cont, socket}
  end

  @impl true
  def mount(_params, session, socket) do
    videos = Video.list_videos()

    # Load random frames for the sliding background
    random_frames = Video.get_random_frames(30)

    search_form = %{"term" => ""}

    # Show welcome modal if explicitly set in session (for new users)
    show_welcome_modal = Map.get(session, "show_welcome_modal", false)

    socket =
      socket
      |> assign(:search_form, search_form)
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:loading, false)
      |> assign(:videos, videos)
      |> assign(:show_video_modal, false)
      |> assign(:selected_video_ids, [])
      |> assign(:search_mode, :global)
      |> assign(:show_sequence_modal, false)
      |> assign(:frame_sequence, nil)
      |> assign(:selected_frame_indices, [])
      |> assign(:autocomplete_suggestions, [])
      |> assign(:show_autocomplete, false)
      |> assign(:expanded_videos, MapSet.new())  # Track which videos are expanded
      |> assign(:frame_sequence_version, 0)
      |> assign(:show_welcome_modal, show_welcome_modal)
      |> assign(:gif_generation_status, nil)
      |> assign(:generated_gif_data, nil)
      |> assign(:ffmpeg_status, nil)
      |> assign(:client_download_url, nil)
      |> assign(:random_frames, random_frames)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Check if this is a shared link and show a helpful message
    socket =
      if Map.get(params, "shared") == "1" && Map.has_key?(params, "frame_ids") do
        put_flash(socket, :info, "Viewing shared frame selection! These are the frames someone wanted to show you.")
      else
        socket
      end

    # Only handle URL params if we don't already have a frame sequence open
    # This prevents URL updates from overriding expanded sequences
    socket =
      socket
      |> assign(:current_params, params)
      |> handle_video_selection_from_params(params)

    socket =
      if socket.assigns.show_sequence_modal do
        # Don't override existing frame sequence if modal is already open
        socket
      else
        handle_frame_selection_from_params(socket, params)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"term" => term}}, socket) when term != "" do
    send(self(), {:perform_search, term})

    socket =
      socket
      |> assign(:search_term, term)
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
    send(self(), {:perform_search, term})

    socket =
      socket
      |> assign(:search_term, term)
      |> assign(:loading, true)
      |> assign(:search_results, [])

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

  # Catch-all for any other search patterns to handle gracefully
  def handle_event("search", params, socket) do
    # Extract term from various possible parameter structures
    term = case params do
      %{"term" => term} -> term
      %{"search_term" => term} -> term
      _ -> ""
    end

    if term != "" do
      send(self(), {:perform_search, term})

      socket =
        socket
        |> assign(:search_term, term)
        |> assign(:loading, true)
        |> assign(:search_results, [])

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:search_term, "")
        |> assign(:search_results, [])
        |> assign(:loading, false)

      {:noreply, socket}
    end
  end

  def handle_event("generate_random_clip", _params, socket) do
    IO.puts("🎬 DEBUG: generate_random_clip event received!")

    case generate_random_5_second_clip() do
      {:ok, clip_data} ->
        IO.puts("🎬 DEBUG: Generated clip: #{inspect(clip_data)}")

        # Open the frame sequence modal directly with the random clip
        socket =
          socket
          |> assign(:frame_sequence, clip_data.frame_sequence)
          |> assign(:selected_frame_indices, clip_data.selected_indices)
          |> assign(:show_sequence_modal, true)
          |> assign(:frame_sequence_version, socket.assigns.frame_sequence_version + 1)
          |> put_flash(:info, "🎬 Random 5-second Nathan clip generated!")

        {:noreply, socket}

      {:error, reason} ->
        IO.puts("🎬 DEBUG: Error generating clip: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "The plan didn't work... (#{reason})")

        {:noreply, socket}
    end
  end

  def handle_event("search_category", %{"category" => category}, socket) do
    IO.puts("DEBUG: search_category event received for: #{category}")

    # Map category to search terms
    search_term = case category do
      "awkward silence" -> "pause"
      "business genius" -> "business"
      "confused stare" -> "confused"
      "summit ice" -> "summit ice"
      _ -> category
    end

    IO.puts("DEBUG: Mapped to search term: #{search_term}")

    send(self(), {:perform_search, search_term})

    socket =
      socket
      |> assign(:search_term, search_term)
      |> assign(:loading, true)
      |> assign(:search_results, [])
      |> put_flash(:info, "🎭 Searching for #{category} moments...")

    {:noreply, socket}
  end

  def handle_event("toggle_video_modal", _params, socket) do
    {:noreply, assign(socket, :show_video_modal, !socket.assigns.show_video_modal)}
  end

  def handle_event("toggle_video_selection", %{"video_id" => video_id}, socket) do
    try do
      video_id = String.to_integer(video_id)
      current_selected = socket.assigns.selected_video_ids

      new_selected_ids = Search.update_video_filter(current_selected, video_id)

      socket =
        socket
        |> assign(:selected_video_ids, new_selected_ids)
        |> push_video_selection_to_url()

      {:noreply, socket}
    rescue
      ArgumentError ->
        socket = put_flash(socket, :error, "Invalid video ID")
        {:noreply, socket}
    end
  end

  def handle_event("apply_video_filter", _params, socket) do
    search_mode = Search.determine_search_mode(socket.assigns.selected_video_ids)

    socket =
      socket
      |> assign(:search_mode, search_mode)
      |> assign(:show_video_modal, false)
      |> assign(:search_results, [])

    {:noreply, socket}
  end

  def handle_event("clear_video_filter", _params, socket) do
    socket =
      socket
      |> assign(:selected_video_ids, [])
      |> assign(:search_mode, :global)
      |> assign(:search_results, [])
      |> push_video_selection_to_url()

    {:noreply, socket}
  end

  def handle_event("select_all_videos", _params, socket) do
    all_video_ids = Enum.map(socket.assigns.videos, & &1.id)
    search_mode = Search.determine_search_mode(all_video_ids)

    socket =
      socket
      |> assign(:selected_video_ids, all_video_ids)
      |> assign(:search_mode, search_mode)

    {:noreply, socket}
  end

  def handle_event("clear_video_selection", _params, socket) do
    socket =
      socket
      |> assign(:selected_video_ids, [])
      |> assign(:search_mode, :global)

    {:noreply, socket}
  end

  def handle_event("process_video", %{"video_path" => video_path}, socket) do
    try do
      case NathanForUs.VideoProcessing.process_video(video_path) do
        {:ok, video} ->
          socket =
            socket
            |> put_flash(:info, "Video '#{video.title}' queued for processing")
            |> assign(:videos, Video.list_videos())

          {:noreply, socket}

        {:error, _changeset} ->
          socket = put_flash(socket, :error, "Failed to queue video for processing")
          {:noreply, socket}
      end
    rescue
      ArgumentError ->
        # Video processing is disabled (e.g., in test environment)
        socket = put_flash(socket, :error, "Video processing is currently unavailable")
        {:noreply, socket}
    end
  end

  def handle_event("show_frame_sequence", %{"frame_id" => frame_id}, socket) do
    try do
      frame_id = String.to_integer(frame_id)

      case Video.get_frame_sequence(frame_id) do
        {:ok, frame_sequence} ->
          # Select all frames by default
          all_frame_indices = 0..(length(frame_sequence.sequence_frames) - 1) |> Enum.to_list()

          socket =
            socket
            |> assign(:frame_sequence, frame_sequence)
            |> assign(:show_sequence_modal, true)
            |> assign(:selected_frame_indices, all_frame_indices)
            |> push_frame_selection_to_url()

          {:noreply, socket}

        {:error, _reason} ->
          socket = put_flash(socket, :error, "Could not load frame sequence")
          {:noreply, socket}
      end
    rescue
      ArgumentError ->
        socket = put_flash(socket, :error, "Invalid frame ID")
        {:noreply, socket}
    end
  end

  def handle_event("close_sequence_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_sequence_modal, false)
      |> assign(:frame_sequence, nil)
      |> assign(:selected_frame_indices, [])
      |> assign(:gif_generation_status, nil)
      |> assign(:generated_gif_data, nil)
      |> assign(:ffmpeg_status, nil)
      |> assign(:client_download_url, nil)
      |> push_frame_selection_to_url()

    {:noreply, socket}
  end

  def handle_event("toggle_frame_selection", %{"frame_index" => frame_index_str}, socket) do
    try do
      frame_index = String.to_integer(frame_index_str)
      current_selected = socket.assigns.selected_frame_indices

      new_selected =
        if frame_index in current_selected do
          List.delete(current_selected, frame_index)
        else
          [frame_index | current_selected] |> Enum.sort()
        end

      socket =
        socket
        |> assign(:selected_frame_indices, new_selected)
        |> push_frame_selection_to_url()

      {:noreply, socket}
    rescue
      ArgumentError ->
        socket = put_flash(socket, :error, "Invalid frame index")
        {:noreply, socket}
    end
  end

  def handle_event("select_all_frames", _params, socket) do
    all_frame_indices = 0..(length(socket.assigns.frame_sequence.sequence_frames) - 1) |> Enum.to_list()
    socket =
      socket
      |> assign(:selected_frame_indices, all_frame_indices)
      |> push_frame_selection_to_url()

    {:noreply, socket}
  end

  def handle_event("deselect_all_frames", _params, socket) do
    socket =
      socket
      |> assign(:selected_frame_indices, [])
      |> push_frame_selection_to_url()

    {:noreply, socket}
  end

  def handle_event("expand_sequence_backward", _params, socket) do
    require Logger
    Logger.info("Expand sequence backward clicked")

    case socket.assigns.frame_sequence do
      nil ->
        Logger.info("No frame sequence found")
        {:noreply, socket}
      frame_sequence ->
        Logger.info("Current sequence: #{frame_sequence.sequence_info.start_frame_number}-#{frame_sequence.sequence_info.end_frame_number}")

        # Get one frame before the current sequence start
        case Search.expand_frame_sequence_backward(frame_sequence) do
          {:ok, expanded_sequence} ->
            Logger.info("Expanded sequence: #{expanded_sequence.sequence_info.start_frame_number}-#{expanded_sequence.sequence_info.end_frame_number}")

            # Update selected indices to account for the new frame at the beginning
            # and automatically select the new frame (index 0)
            updated_indices = [0 | Enum.map(socket.assigns.selected_frame_indices, fn index -> index + 1 end)]
            Logger.info("Updated selected indices with new frame: #{inspect(updated_indices)}")

            socket =
              socket
              |> assign(:frame_sequence, expanded_sequence)
              |> assign(:selected_frame_indices, updated_indices)
              |> assign(:frame_sequence_version, socket.assigns.frame_sequence_version + 1)
              |> push_frame_selection_to_url()

            {:noreply, socket}

          {:error, reason} ->
            Logger.info("Expand backward failed: #{inspect(reason)}")
            {:noreply, socket}
        end
    end
  end

  def handle_event("expand_sequence_forward", _params, socket) do
    require Logger
    Logger.info("Expand sequence forward clicked")

    case socket.assigns.frame_sequence do
      nil ->
        Logger.info("No frame sequence found")
        {:noreply, socket}
      frame_sequence ->
        Logger.info("Current sequence: #{frame_sequence.sequence_info.start_frame_number}-#{frame_sequence.sequence_info.end_frame_number}")

        # Get one frame after the current sequence end
        case Search.expand_frame_sequence_forward(frame_sequence) do
          {:ok, expanded_sequence} ->
            Logger.info("Expanded sequence: #{expanded_sequence.sequence_info.start_frame_number}-#{expanded_sequence.sequence_info.end_frame_number}")

            # Selected indices stay the same since we're adding at the end
            # but also automatically select the new frame (last index)
            new_frame_index = length(expanded_sequence.sequence_frames) - 1
            updated_indices = socket.assigns.selected_frame_indices ++ [new_frame_index]

            socket =
              socket
              |> assign(:frame_sequence, expanded_sequence)
              |> assign(:selected_frame_indices, updated_indices)
              |> assign(:frame_sequence_version, socket.assigns.frame_sequence_version + 1)
              |> push_frame_selection_to_url()

            {:noreply, socket}

          {:error, reason} ->
            Logger.info("Expand forward failed: #{inspect(reason)}")
            {:noreply, socket}
        end
    end
  end

  def handle_event("expand_sequence_backward_multiple", params, socket) do
    require Logger
    Logger.info("Received expand_sequence_backward_multiple event with params: #{inspect(params)}")

    count_str = Map.get(params, "value", "")
    Logger.info("Extracted count_str: #{inspect(count_str)}")

    case {socket.assigns.frame_sequence, count_str} do
      {nil, _} ->
        Logger.info("No frame sequence available")
        {:noreply, socket}

      {_, ""} ->
        Logger.info("Empty value provided")
        {:noreply, socket}

      {frame_sequence, count_str} ->
        try do
          count = String.to_integer(count_str)
          Logger.info("Parsed count: #{count}")

          case count do
            c when c >= 1 and c <= 20 ->
              Logger.info("Expanding backward by #{count} frames")
              Logger.info("Current sequence frames: #{length(frame_sequence.sequence_frames)}")
              Logger.info("Current start frame: #{frame_sequence.sequence_info.start_frame_number}")
              Logger.info("Current end frame: #{frame_sequence.sequence_info.end_frame_number}")

              # Expand backward multiple times
              {final_sequence, total_added} = expand_backward_multiple(frame_sequence, count, 0)
              Logger.info("Final sequence frames: #{length(final_sequence.sequence_frames)}, added: #{total_added}")
              Logger.info("Final start frame: #{final_sequence.sequence_info.start_frame_number}")
              Logger.info("Final end frame: #{final_sequence.sequence_info.end_frame_number}")

              if total_added > 0 do
                # Add new indices for all added frames (they'll be at indices 0 to total_added-1)
                new_indices = Enum.to_list(0..(total_added-1))
                # Shift existing indices by total_added
                shifted_existing = Enum.map(socket.assigns.selected_frame_indices, &(&1 + total_added))
                updated_indices = (new_indices ++ shifted_existing) |> Enum.uniq() |> Enum.sort()

                socket =
                  socket
                  |> assign(:frame_sequence, final_sequence)
                  |> assign(:selected_frame_indices, updated_indices)
                  |> assign(:frame_sequence_version, socket.assigns.frame_sequence_version + 1)
                  |> push_frame_selection_to_url()
                  |> push_event("clear_expand_form", %{target: "expand-backward-form"})

                {:noreply, socket}
              else
                Logger.info("No frames were added")
                {:noreply, socket}
              end

            _ ->
              Logger.info("Invalid count: #{count}")
              {:noreply, socket}
          end
        rescue
          ArgumentError ->
            Logger.info("Failed to parse count_str: #{inspect(count_str)}")
            {:noreply, socket}
        end
    end
  end

  def handle_event("expand_sequence_forward_multiple", params, socket) do
    require Logger
    Logger.info("Received expand_sequence_forward_multiple event with params: #{inspect(params)}")

    count_str = Map.get(params, "value", "")
    Logger.info("Extracted count_str: #{inspect(count_str)}")

    case {socket.assigns.frame_sequence, count_str} do
      {nil, _} ->
        Logger.info("No frame sequence available")
        {:noreply, socket}

      {_, ""} ->
        Logger.info("Empty value provided")
        {:noreply, socket}

      {frame_sequence, count_str} ->
        try do
          count = String.to_integer(count_str)
          Logger.info("Parsed count: #{count}")

          case count do
            c when c >= 1 and c <= 20 ->
              Logger.info("Expanding forward by #{count} frames")
              Logger.info("Current sequence frames: #{length(frame_sequence.sequence_frames)}")
              Logger.info("Current start frame: #{frame_sequence.sequence_info.start_frame_number}")
              Logger.info("Current end frame: #{frame_sequence.sequence_info.end_frame_number}")

              # Expand forward multiple times
              {final_sequence, total_added} = expand_forward_multiple(frame_sequence, count, 0)
              Logger.info("Final sequence frames: #{length(final_sequence.sequence_frames)}, added: #{total_added}")
              Logger.info("Final start frame: #{final_sequence.sequence_info.start_frame_number}")
              Logger.info("Final end frame: #{final_sequence.sequence_info.end_frame_number}")

              if total_added > 0 do
                # Add new indices for all added frames (they'll be at the end)
                original_length = length(socket.assigns.frame_sequence.sequence_frames)
                new_indices = Enum.to_list(original_length..(original_length + total_added - 1))
                updated_indices = (socket.assigns.selected_frame_indices ++ new_indices) |> Enum.uniq() |> Enum.sort()

                socket =
                  socket
                  |> assign(:frame_sequence, final_sequence)
                  |> assign(:selected_frame_indices, updated_indices)
                  |> assign(:frame_sequence_version, socket.assigns.frame_sequence_version + 1)
                  |> push_frame_selection_to_url()
                  |> push_event("clear_expand_form", %{target: "expand-forward-form"})

                {:noreply, socket}
              else
                Logger.info("No frames were added")
                {:noreply, socket}
              end

            _ ->
              Logger.info("Invalid count: #{count}")
              {:noreply, socket}
          end
        rescue
          ArgumentError ->
            Logger.info("Failed to parse count_str: #{inspect(count_str)}")
            {:noreply, socket}
        end
    end
  end

  def handle_event("autocomplete_search", %{"search" => %{"term" => term}}, socket) do
    search_form = %{"term" => term}

    if String.length(term) >= 3 do
      suggestions = Search.get_autocomplete_suggestions(term, socket.assigns.search_mode, socket.assigns.selected_video_ids)

      socket =
        socket
        |> assign(:search_form, search_form)
        |> assign(:search_term, term)
        |> assign(:autocomplete_suggestions, suggestions)
        |> assign(:show_autocomplete, true)

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:search_form, search_form)
        |> assign(:search_term, term)
        |> assign(:autocomplete_suggestions, [])
        |> assign(:show_autocomplete, false)

      {:noreply, socket}
    end
  end

  def handle_event("select_suggestion", %{"suggestion" => suggestion}, socket) do
    # Only populate the search field, don't trigger search
    search_form = %{"term" => suggestion}

    socket =
      socket
      |> assign(:search_form, search_form)
      |> assign(:search_term, suggestion)
      |> assign(:show_autocomplete, false)
      |> assign(:autocomplete_suggestions, [])

    {:noreply, socket}
  end

  def handle_event("hide_autocomplete", _params, socket) do
    socket = assign(socket, :show_autocomplete, false)
    {:noreply, socket}
  end

  def handle_event("close_welcome_modal", _params, socket) do
    {:noreply, assign(socket, :show_welcome_modal, false)}
  end

  def handle_event("show_welcome_for_first_visit", _params, socket) do
    # Client-side determined this is a first visit, show the modal
    {:noreply, assign(socket, :show_welcome_modal, true)}
  end

  def handle_event("ignore", _params, socket) do
    # Ignore events (e.g. from animation speed slider)
    {:noreply, socket}
  end

  def handle_event("generate_gif", _params, socket) do
    case {socket.assigns.frame_sequence, socket.assigns.selected_frame_indices} do
      {frame_sequence, selected_indices} when not is_nil(frame_sequence) and length(selected_indices) > 0 ->
        # Start async GIF generation
        task = Task.async(fn ->
          NathanForUs.AdminService.generate_gif_from_frames(frame_sequence, selected_indices)
        end)

        socket =
          socket
          |> assign(:gif_generation_status, :generating)
          |> assign(:gif_generation_task, task)
          |> assign(:generated_gif_data, nil)

        {:noreply, socket}

      {nil, _} ->
        socket = put_flash(socket, :error, "No frame sequence available")
        {:noreply, socket}

      {_, []} ->
        socket = put_flash(socket, :error, "No frames selected for GIF generation")
        {:noreply, socket}
    end
  end

  def handle_event("generate_gif_client", _params, socket) do
    case {socket.assigns.frame_sequence, socket.assigns.selected_frame_indices} do
      {frame_sequence, selected_indices} when not is_nil(frame_sequence) and length(selected_indices) > 0 ->
        # Get selected frames based on indices
        selected_frames =
          selected_indices
          |> Enum.map(&Enum.at(frame_sequence.sequence_frames, &1))
          |> Enum.reject(&is_nil/1)

        # Convert frame data to the format expected by JavaScript
        frame_data = Enum.map(selected_frames, fn frame ->
          %{
            id: frame.id,
            image_data: if Map.get(frame, :image_data) do
              case String.starts_with?(frame.image_data, "\\x") do
                true ->
                  # Remove the \x prefix and decode from hex
                  hex_string = String.slice(frame.image_data, 2..-1//1)
                  case Base.decode16(hex_string, case: :lower) do
                    {:ok, binary_data} -> Base.encode64(binary_data)
                    :error -> ""
                  end
                false ->
                  # Already binary data, encode directly
                  Base.encode64(frame.image_data)
              end
            else
              ""
            end,
            frame_number: frame.frame_number,
            timestamp_ms: frame.timestamp_ms
          }
        end)

        socket =
          socket
          |> assign(:gif_generation_status, :generating)
          |> assign(:generated_gif_data, nil)
          |> assign(:client_download_url, nil)
          |> push_event("start_gif_generation", %{frames: frame_data, fps: 6})

        {:noreply, socket}

      {nil, _} ->
        socket = put_flash(socket, :error, "No frame sequence available")
        {:noreply, socket}

      {_, []} ->
        socket = put_flash(socket, :error, "No frames selected for GIF generation")
        {:noreply, socket}
    end
  end

  def handle_event("generate_gif_server", _params, socket) do
    # This is the same as the original generate_gif but with explicit naming
    handle_event("generate_gif", %{}, socket)
  end

  def handle_event("gif_status_update", %{"status" => status, "message" => message}, socket) do
    ffmpeg_status = %{status: status, message: message}
    socket = assign(socket, :ffmpeg_status, ffmpeg_status)
    {:noreply, socket}
  end

  def handle_event("gif_generation_complete", %{"download_url" => download_url}, socket) do
    require Logger
    Logger.info("Received gif_generation_complete with download_url: #{inspect(download_url)}")

    socket =
      socket
      |> assign(:gif_generation_status, :completed)
      |> assign(:client_download_url, download_url)
      |> assign(:ffmpeg_status, nil)
      |> put_flash(:info, "GIF generated successfully on client!")

    {:noreply, socket}
  end

  def handle_event("toggle_video_expansion", %{"video_id" => video_id_str}, socket) do
    try do
      video_id = String.to_integer(video_id_str)
      expanded_videos = socket.assigns.expanded_videos

      updated_expanded =
        if MapSet.member?(expanded_videos, video_id) do
          MapSet.delete(expanded_videos, video_id)
        else
          MapSet.put(expanded_videos, video_id)
        end

      # Update the search results to reflect the new expanded state
      updated_results = update_video_expansion_state(socket.assigns.search_results, updated_expanded)

      socket =
        socket
        |> assign(:expanded_videos, updated_expanded)
        |> assign(:search_results, updated_results)

      {:noreply, socket}
    rescue
      ArgumentError ->
        socket = put_flash(socket, :error, "Invalid video ID")
        {:noreply, socket}
    end
  end

  # Helper function to update expansion state in search results
  defp update_video_expansion_state(search_results, expanded_videos) do
    Enum.map(search_results, fn video_result ->
      Map.put(video_result, :expanded, MapSet.member?(expanded_videos, video_result.video_id))
    end)
  end

  # Handle video selection from URL parameters
  defp handle_video_selection_from_params(socket, params) do
    case Map.get(params, "video") do
      nil -> socket
      video_id_str ->
        try do
          video_id = String.to_integer(video_id_str)

          # Validate video exists
          if Enum.find(socket.assigns.videos, &(&1.id == video_id)) do
            socket
            |> assign(:selected_video_ids, [video_id])
            |> assign(:search_mode, :filtered)
          else
            socket
          end
        rescue
          ArgumentError -> socket
        end
    end
  end

  # Handle frame selection from URL parameters
  defp handle_frame_selection_from_params(socket, params) do
    case Map.get(params, "frame") do
      nil -> socket
      frame_id_str ->
        try do
          frame_id = String.to_integer(frame_id_str)

          # Check if we have specific frame IDs or need to parse indices
          frame_sequence_result = case Map.get(params, "frame_ids") do
            nil ->
              # Legacy: Parse selected frames from URL indices
              selected_indices = parse_selected_frames_from_params(params)
              if Enum.empty?(selected_indices) do
                Video.get_frame_sequence(frame_id)
              else
                Video.get_frame_sequence_with_selected_indices(frame_id, selected_indices)
              end
            frame_ids_str ->
              # New: Use specific frame IDs
              frame_ids = parse_frame_ids_from_params(frame_ids_str)
              Video.get_frame_sequence_from_frame_ids(frame_id, frame_ids)
          end

          case frame_sequence_result do
            {:ok, frame_sequence} ->
              # For frame_ids approach, select all frames; for legacy indices, use those
              final_selected_indices = case Map.get(params, "frame_ids") do
                nil ->
                  # Legacy: use parsed indices or select all
                  selected_indices = parse_selected_frames_from_params(params)
                  if Enum.empty?(selected_indices) do
                    0..(length(frame_sequence.sequence_frames) - 1) |> Enum.to_list()
                  else
                    selected_indices
                  end
                _ ->
                  # New: select all frames since we got exactly what we wanted
                  0..(length(frame_sequence.sequence_frames) - 1) |> Enum.to_list()
              end

              socket
              |> assign(:frame_sequence, frame_sequence)
              |> assign(:show_sequence_modal, true)
              |> assign(:selected_frame_indices, final_selected_indices)

            {:error, _reason} ->
              socket
          end
        rescue
          ArgumentError -> socket
        end
    end
  end

  # Parse selected frame indices from URL parameters
  defp parse_selected_frames_from_params(params) do
    case Map.get(params, "frames") do
      nil -> []
      "" -> []  # Handle empty string
      frames_str ->
        frames_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))  # Reject empty strings
        |> Enum.reduce([], fn frame_str, acc ->
          try do
            frame_index = String.to_integer(frame_str)
            [frame_index | acc]
          rescue
            ArgumentError -> acc
          end
        end)
        |> Enum.uniq()  # Remove duplicates
        |> Enum.sort()
    end
  end

  defp parse_frame_ids_from_params(frame_ids_str) do
    frame_ids_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce([], fn frame_id_str, acc ->
      try do
        frame_id = String.to_integer(frame_id_str)
        [frame_id | acc]
      rescue
        ArgumentError -> acc
      end
    end)
    |> Enum.uniq()
    |> Enum.reverse()  # Keep original order
  end

  # Update URL with current video selection
  defp push_video_selection_to_url(socket) do
    current_params = get_current_url_params(socket)

    new_params = case socket.assigns.selected_video_ids do
      [] -> Map.delete(current_params, "video")
      [video_id] -> Map.put(current_params, "video", to_string(video_id))
      _ -> current_params # Multiple videos not supported in URL yet
    end

    push_patch(socket, to: build_url_with_params("/video-search", new_params))
  end

  # Update URL with current frame selection
  defp push_frame_selection_to_url(socket) do
    current_params = get_current_url_params(socket)

    new_params = case {socket.assigns.frame_sequence, socket.assigns.selected_frame_indices} do
      {nil, _} ->
        current_params
        |> Map.delete("frame")
        |> Map.delete("frames")

      {frame_sequence, []} ->
        current_params
        |> Map.put("frame", to_string(frame_sequence.target_frame.id))
        |> Map.delete("frames")

      {frame_sequence, selected_indices} ->
        frames_str = selected_indices |> Enum.sort() |> Enum.join(",")
        current_params
        |> Map.put("frame", to_string(frame_sequence.target_frame.id))
        |> Map.put("frames", frames_str)
    end

    push_patch(socket, to: build_url_with_params("/video-search", new_params))
  end

  # Get current URL parameters
  defp get_current_url_params(socket) do
    # Extract current URL parameters from socket context
    socket.assigns[:current_params] || %{}
  end

  # Build URL with parameters
  defp build_url_with_params(path, params) when params == %{}, do: path
  defp build_url_with_params(path, params) do
    query_string = URI.encode_query(params)
    "#{path}?#{query_string}"
  end

  # Helper function to expand backward multiple times
  defp expand_backward_multiple(frame_sequence, count, added_so_far) when count > 0 do
    case Search.expand_frame_sequence_backward(frame_sequence) do
      {:ok, expanded_sequence} ->
        expand_backward_multiple(expanded_sequence, count - 1, added_so_far + 1)

      {:error, _reason} ->
        {frame_sequence, added_so_far}
    end
  end

  defp expand_backward_multiple(frame_sequence, 0, added_so_far) do
    {frame_sequence, added_so_far}
  end

  # Helper function to expand forward multiple times
  defp expand_forward_multiple(frame_sequence, count, added_so_far) when count > 0 do
    case Search.expand_frame_sequence_forward(frame_sequence) do
      {:ok, expanded_sequence} ->
        expand_forward_multiple(expanded_sequence, count - 1, added_so_far + 1)

      {:error, _reason} ->
        {frame_sequence, added_so_far}
    end
  end

  defp expand_forward_multiple(frame_sequence, 0, added_so_far) do
    {frame_sequence, added_so_far}
  end

  @impl true
  def handle_info({:perform_search, term}, socket) when is_binary(term) do
    case Search.search_frames(term, socket.assigns.search_mode, socket.assigns.selected_video_ids) do
      {:ok, results} ->
        # Clear expanded state for new searches - all videos start collapsed
        socket =
          socket
          |> assign(:search_results, results)
          |> assign(:loading, false)
          |> assign(:expanded_videos, MapSet.new())

        {:noreply, socket}

      {:error, reason} ->
        nathan_error_messages = [
          "This didn't go according to the plan...",
          "I wasn't prepared for this outcome...",
          "The strategy needs adjustment...",
          "Time to pivot and try again...",
          "This calls for a new approach..."
        ]

        error_message = "#{Enum.random(nathan_error_messages)} (#{reason})"

        socket =
          socket
          |> assign(:search_results, [])
          |> assign(:loading, false)
          |> put_flash(:error, error_message)

        {:noreply, socket}
    end
  end

  def handle_info({:perform_search, nil}, socket) do
    socket =
      socket
      |> assign(:search_results, [])
      |> assign(:loading, false)

    {:noreply, socket}
  end

  def handle_info({:perform_search, _invalid_term}, socket) do
    socket =
      socket
      |> assign(:search_results, [])
      |> assign(:loading, false)
      |> put_flash(:error, "I may have misunderstood the assignment... (Invalid search term)")

    {:noreply, socket}
  end

  def handle_info({ref, result}, socket) do
    # Handle GIF generation task completion
    if socket.assigns[:gif_generation_task] && socket.assigns.gif_generation_task.ref == ref do
      Process.demonitor(ref, [:flush])

      case result do
        {:ok, gif_data} ->
          # Convert binary data to base64 for embedding
          gif_base64 = Base.encode64(gif_data)

          success_messages = [
            "The plan worked perfectly! 🎬",
            "Business genius strikes again! 📈",
            "Another successful operation! 🎯",
            "Everything went according to plan! ✨",
            "Mission accomplished! 🏆"
          ]

          socket =
            socket
            |> assign(:gif_generation_status, :completed)
            |> assign(:generated_gif_data, gif_base64)
            |> assign(:gif_generation_task, nil)
            |> put_flash(:info, Enum.random(success_messages))

          {:noreply, socket}

        {:error, reason} ->
          error_messages = [
            "This didn't go as planned...",
            "The strategy needs adjustment...",
            "Time to pivot and try again...",
            "I wasn't prepared for this outcome..."
          ]

          socket =
            socket
            |> assign(:gif_generation_status, nil)
            |> assign(:gif_generation_task, nil)
            |> put_flash(:error, "#{Enum.random(error_messages)} (#{reason})")

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    # Handle GIF generation task crash
    if socket.assigns[:gif_generation_task] && socket.assigns.gif_generation_task.ref == ref do
      crash_messages = [
        "This is not going according to plan...",
        "I need to go back to the drawing board...",
        "The rehearsal didn't prepare me for this...",
        "Time for a complete strategy overhaul..."
      ]

      socket =
        socket
        |> assign(:gif_generation_status, nil)
        |> assign(:gif_generation_task, nil)
        |> put_flash(:error, "#{Enum.random(crash_messages)} (Process crashed: #{inspect(reason)})")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Welcome Modal for New Users -->
    <%= if @show_welcome_modal do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
        <div class="bg-white rounded-lg shadow-xl max-w-lg mx-4 p-6">
          <div class="text-center">
            <h2 class="text-2xl font-bold text-gray-900 mb-4">Welcome to Nathan For Us!</h2>
            <div class="text-left space-y-3 text-sm text-gray-700 mb-6">
              <p><strong>🎬 Search for any Nathan quote and find the exact frame!</strong></p>
              <p>• Type in quotes like <code class="bg-gray-100 px-1 rounded">"I graduated from business school"</code></p>
              <p>• Click frames to create animated GIFs</p>
              <p>• Use the video filter to search specific interviews</p>
              <p>• Expand frame sequences to get more context</p>
              <p class="text-blue-600 font-medium">Start by searching for something Nathan said in any of his interviews!</p>
            </div>
            <button
              id="welcome-close-button"
              phx-click="close_welcome_modal"
              phx-hook="VideoSearchVisited"
              class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium transition-colors"
            >
              Got it, let's search!
            </button>
          </div>
        </div>
      </div>
    <% end %>

    <!-- Sliding Background Container -->
    <div
      id="sliding-background-container"
      phx-hook="SlidingBackground"
      data-frames={Jason.encode!(@random_frames)}
      class="min-h-screen relative overflow-hidden"
    >
      <!-- Background Frame Display -->
      <div class="sliding-background absolute inset-0 bg-cover bg-center bg-no-repeat transition-all duration-2000 ease-in-out opacity-60 filter blur-sm"
           style="background-size: cover; background-position: center;">
      </div>

      <!-- Background Overlay -->
      <div class="absolute inset-0 bg-zinc-50/60 backdrop-blur-sm"></div>

      <!-- Main Content -->
      <div id="video-search" phx-hook="VideoSearchWelcome" class="relative z-10 min-h-screen text-zinc-900 p-4 md:p-6 font-mono">
        <div class="max-w-5xl mx-auto">
          <SearchHeader.search_header search_term={@search_term} results_count={length(@search_results)} />

          <div class="space-y-4">
            <SearchInterface.search_interface
              search_term={@search_term}
              search_form={@search_form}
              loading={@loading}
              videos={@videos}
              search_mode={@search_mode}
              selected_video_ids={@selected_video_ids}
              autocomplete_suggestions={@autocomplete_suggestions}
              show_autocomplete={@show_autocomplete}
            />

            <SearchResults.search_results
              :if={!@loading}
              search_results={@search_results}
              search_term={@search_term}
            />

            <SearchResults.loading_state :if={@loading} search_term={@search_term} />
          </div>

          <VideoFilter.video_filter_modal
            :if={@show_video_modal}
            videos={@videos}
            selected_video_ids={@selected_video_ids}
          />

          <FrameSequence.frame_sequence_modal
            :if={@show_sequence_modal}
            frame_sequence={@frame_sequence}
            selected_frame_indices={@selected_frame_indices}
            frame_sequence_version={@frame_sequence_version}
            gif_generation_status={@gif_generation_status}
            generated_gif_data={@generated_gif_data}
            ffmpeg_status={@ffmpeg_status}
            client_download_url={@client_download_url}
          />
        </div>
      </div>
    </div>

    """
  end

  @doc """
  Generates a share URL for the selected frames that other users can use to see the same selection.
  """
  def generate_share_url(frame_sequence, selected_frame_indices) do
    if frame_sequence && !Enum.empty?(selected_frame_indices) do
      # Get the frame IDs of the selected frames
      selected_frames =
        selected_frame_indices
        |> Enum.map(fn index ->
          Enum.at(frame_sequence.sequence_frames, index)
        end)
        |> Enum.filter(& &1)
        |> Enum.map(& &1.id)

      # Generate the share URL with frame IDs
      if !Enum.empty?(selected_frames) do
        base_frame_id = hd(frame_sequence.sequence_frames).id
        frame_ids_param = Enum.join(selected_frames, ",")

        "/video-search?frame=#{base_frame_id}&frame_ids=#{frame_ids_param}&shared=1"
      else
        nil
      end
    else
      nil
    end
  end

  # Private helper functions

  defp generate_random_5_second_clip do
    # Get all available videos
    videos = Video.list_videos()

    case videos do
      [] ->
        {:error, "No videos available"}

      available_videos ->
        # Pick a random video
        random_video = Enum.random(available_videos)

        # Get total frames for this video to pick a random starting point
        case Video.get_video_frame_count(random_video.id) do
          {:ok, total_frames} when total_frames > 30 ->
            # Pick a random starting frame, ensuring we have at least 30 frames left
            # (for a 5-second clip at 6fps)
            max_start_frame = total_frames - 30
            random_start_frame = :rand.uniform(max_start_frame)

            # Generate a frame sequence starting from the random frame
            case Video.get_frame_sequence_by_frame_number(random_video.id, random_start_frame) do
              {:ok, frame_sequence} ->
                # Select all frames for the 5-second clip (up to 30 frames for 5 seconds at 6fps)
                frame_count = min(30, length(frame_sequence.sequence_frames))
                selected_indices = Enum.to_list(0..(frame_count - 1))

                {:ok, %{
                  frame_sequence: frame_sequence,
                  selected_indices: selected_indices
                }}

              {:error, reason} ->
                {:error, "Could not load frame sequence: #{reason}"}
            end

          {:ok, _small_frame_count} ->
            {:error, "Video too short for 5-second clip"}
        end
    end
  end

end
