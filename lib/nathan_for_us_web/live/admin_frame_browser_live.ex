defmodule NathanForUsWeb.AdminFrameBrowserLive do
  use NathanForUsWeb, :live_view

  on_mount {NathanForUsWeb.UserAuth, :ensure_admin}

  alias NathanForUs.{Video, AdminService}

  @impl true
  def mount(_params, _session, socket) do
    videos = Video.list_videos()
    
    socket =
      socket
      |> assign(:videos, videos)
      |> assign(:selected_video, nil)
      |> assign(:frames, [])
      |> assign(:selected_frame_indices, [])
      |> assign(:current_page, 1)
      |> assign(:frames_per_page, 50)
      |> assign(:total_frames, 0)
      |> assign(:gif_generation_status, nil)
      |> assign(:gif_generation_task, nil)
      |> assign(:generated_gif_data, nil)
      |> assign(:ffmpeg_status, nil)
      |> assign(:client_download_url, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case Map.get(params, "video_id") do
      nil ->
        {:noreply, socket}
      video_id_string ->
        case Integer.parse(video_id_string) do
          {video_id, ""} ->
            case Video.get_video(video_id) do
              {:ok, video} ->
                socket = load_video_frames(socket, video)
                {:noreply, socket}
              {:error, _} ->
                socket =
                  socket
                  |> put_flash(:error, "Video not found")
                  |> push_patch(to: ~p"/admin/frames")
                {:noreply, socket}
            end
          _ ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("select_video", %{"video_id" => video_id_string}, socket) do
    case Integer.parse(video_id_string) do
      {video_id, ""} ->
        {:noreply, push_patch(socket, to: ~p"/admin/frames?video_id=#{video_id}")}
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid video ID")}
    end
  end

  def handle_event("toggle_frame_selection", %{"frame_index" => frame_index_string}, socket) do
    case Integer.parse(frame_index_string) do
      {frame_index, ""} ->
        selected_indices = socket.assigns.selected_frame_indices
        
        new_indices = 
          if frame_index in selected_indices do
            List.delete(selected_indices, frame_index)
          else
            [frame_index | selected_indices] |> Enum.sort()
          end
        
        {:noreply, assign(socket, :selected_frame_indices, new_indices)}
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid frame index")}
    end
  end

  def handle_event("select_all_frames", _params, socket) do
    frame_count = length(socket.assigns.frames)
    all_indices = Enum.to_list(0..(frame_count - 1))
    {:noreply, assign(socket, :selected_frame_indices, all_indices)}
  end

  def handle_event("deselect_all_frames", _params, socket) do
    {:noreply, assign(socket, :selected_frame_indices, [])}
  end

  def handle_event("change_page", %{"page" => page_string}, socket) do
    case Integer.parse(page_string) do
      {page, ""} when page > 0 ->
        socket = 
          socket
          |> assign(:current_page, page)
          |> assign(:selected_frame_indices, [])
        
        if socket.assigns.selected_video do
          socket = load_video_frames(socket, socket.assigns.selected_video)
          {:noreply, socket}
        else
          {:noreply, socket}
        end
      _ ->
        {:noreply, socket}
    end
  end

  # Legacy handler for compatibility with tests
  def handle_event("generate_gif", _params, socket) do
    handle_event("generate_gif_server", %{}, socket)
  end

  def handle_event("generate_gif_server", _params, socket) do
    selected_indices = socket.assigns.selected_frame_indices
    frames = socket.assigns.frames
    
    if length(selected_indices) == 0 do
      {:noreply, put_flash(socket, :error, "Please select at least one frame to generate a GIF")}
    else
      # Create a frame sequence from selected frames
      selected_frames = 
        selected_indices
        |> Enum.map(&Enum.at(frames, &1))
        |> Enum.reject(&is_nil/1)
      
      if length(selected_frames) == 0 do
        {:noreply, put_flash(socket, :error, "Selected frames not found")}
      else
        # Create a mock frame sequence structure for GIF generation
        first_frame = List.first(selected_frames)
        
        frame_sequence = %{
          target_frame: first_frame,
          sequence_frames: selected_frames,
          target_captions: "",
          sequence_captions: %{},
          sequence_info: %{
            target_frame_number: first_frame.frame_number,
            start_frame_number: List.first(selected_frames).frame_number,
            end_frame_number: List.last(selected_frames).frame_number,
            total_frames: length(selected_frames)
          }
        }
        
        # Adjust indices to be relative to the selected frames
        relative_indices = Enum.to_list(0..(length(selected_frames) - 1))
        
        # Start async GIF generation task
        task = Task.async(fn ->
          AdminService.generate_gif_from_frames(frame_sequence, relative_indices)
        end)
        
        socket =
          socket
          |> assign(:gif_generation_status, :generating)
          |> assign(:gif_generation_task, task)
          |> assign(:generated_gif_data, nil)
        
        {:noreply, socket}
      end
    end
  end

  def handle_event("generate_gif_client", _params, socket) do
    selected_indices = socket.assigns.selected_frame_indices
    frames = socket.assigns.frames
    
    if length(selected_indices) == 0 do
      {:noreply, put_flash(socket, :error, "Please select at least one frame to generate a GIF")}
    else
      # Get selected frames with their image data
      selected_frames = 
        selected_indices
        |> Enum.map(&Enum.at(frames, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&Map.get(&1, :image_data))  # Only frames with image data
      
      if length(selected_frames) == 0 do
        {:noreply, put_flash(socket, :error, "No valid frames with image data found")}
      else
        # Prepare frame data for client-side processing
        frame_urls = Enum.map(selected_frames, fn frame ->
          "data:image/jpeg;base64,#{encode_image_data(frame.image_data)}"
        end)
        
        # Calculate framerate based on video FPS
        video = socket.assigns.selected_video
        base_framerate = if video && video.fps, do: min(video.fps / 2, 12), else: 6
        
        # Send to client for processing
        socket =
          socket
          |> assign(:gif_generation_status, :generating)
          |> assign(:generated_gif_data, nil)
          |> assign(:client_download_url, nil)
          |> push_event("generate_client_gif", %{
            frames: frame_urls,
            options: %{
              framerate: base_framerate,
              width: 600,
              quality: "high"
            }
          })
        
        {:noreply, socket}
      end
    end
  end

  def handle_event("gif_status_update", %{"status" => status, "message" => message}, socket) do
    socket = assign(socket, :ffmpeg_status, %{status: status, message: message})
    {:noreply, socket}
  end

  def handle_event("gif_generation_complete", %{"success" => true, "gifData" => gif_data, "downloadUrl" => download_url}, socket) do
    socket =
      socket
      |> assign(:gif_generation_status, :completed)
      |> assign(:generated_gif_data, gif_data)
      |> assign(:client_download_url, download_url)
      |> put_flash(:info, "GIF generated successfully on your device!")
    
    {:noreply, socket}
  end

  def handle_event("gif_generation_complete", %{"success" => false, "error" => error}, socket) do
    socket =
      socket
      |> assign(:gif_generation_status, nil)
      |> assign(:generated_gif_data, nil)
      |> assign(:client_download_url, nil)
      |> put_flash(:error, "Client-side GIF generation failed: #{error}")
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({task_ref, result}, socket) do
    if socket.assigns.gif_generation_task && socket.assigns.gif_generation_task.ref == task_ref do
      Process.demonitor(task_ref, [:flush])
      
      case result do
        {:ok, gif_data} ->
          socket =
            socket
            |> assign(:gif_generation_status, :completed)
            |> assign(:gif_generation_task, nil)
            |> assign(:generated_gif_data, Base.encode64(gif_data))
            |> put_flash(:info, "GIF generated successfully!")
          
          {:noreply, socket}
        
        {:error, error_message} ->
          socket =
            socket
            |> assign(:gif_generation_status, nil)
            |> assign(:gif_generation_task, nil)
            |> assign(:generated_gif_data, nil)
            |> put_flash(:error, "GIF generation failed: #{error_message}")
          
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, task_ref, :process, _pid, _reason}, socket) do
    if socket.assigns.gif_generation_task && socket.assigns.gif_generation_task.ref == task_ref do
      socket =
        socket
        |> assign(:gif_generation_status, nil)
        |> assign(:gif_generation_task, nil)
        |> assign(:generated_gif_data, nil)
        |> put_flash(:error, "GIF generation task failed")
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp load_video_frames(socket, video) do
    page = socket.assigns.current_page
    per_page = socket.assigns.frames_per_page
    offset = (page - 1) * per_page
    
    {:ok, %{frames: frames, total_count: total_count}} = Video.get_video_frames_with_pagination(video.id, offset, per_page)
    
    socket
    |> assign(:selected_video, video)
    |> assign(:frames, frames)
    |> assign(:total_frames, total_count)
    |> assign(:selected_frame_indices, [])
  end

  defp total_pages(total_frames, frames_per_page) do
    max(1, ceil(total_frames / frames_per_page))
  end

  defp page_range(current_page, total_pages) do
    start_page = max(1, current_page - 2)
    end_page = min(total_pages, current_page + 2)
    Enum.to_list(start_page..end_page)
  end

  defp format_timestamp(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
  defp format_timestamp(_), do: "0:00"

  defp encode_image_data(nil), do: ""
  defp encode_image_data(hex_data) when is_binary(hex_data) do
    case String.starts_with?(hex_data, "\\x") do
      true ->
        hex_string = String.slice(hex_data, 2..-1//1)
        case Base.decode16(hex_string, case: :lower) do
          {:ok, binary_data} -> Base.encode64(binary_data)
          :error -> ""
        end
      false ->
        Base.encode64(hex_data)
    end
  end

  defp format_duration(duration_ms) when is_integer(duration_ms) do
    total_seconds = div(duration_ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
  defp format_duration(_), do: "0:00"

  defp get_frame_captions(frames) do
    frame_ids = Enum.map(frames, & &1.id)
    
    if length(frame_ids) > 0 do
      case Video.get_frames_captions(frame_ids) do
        {:ok, captions_map} -> captions_map
        _ -> %{}
      end
    else
      %{}
    end
  end

  defp get_selected_frames_captions(frames, selected_indices) do
    selected_frames = 
      selected_indices
      |> Enum.map(&Enum.at(frames, &1))
      |> Enum.reject(&is_nil/1)
    
    if length(selected_frames) > 0 do
      captions_map = get_frame_captions(selected_frames)
      
      # Collect all unique captions in chronological order
      unique_captions = 
        selected_frames
        |> Enum.sort_by(& &1.timestamp_ms)  # Sort by timestamp to maintain order
        |> Enum.flat_map(fn frame ->
          Map.get(captions_map, frame.id, [])
        end)
        |> Enum.uniq()  # Remove duplicates
        |> Enum.reject(&(&1 == "" or is_nil(&1)))  # Remove empty captions
        
      case unique_captions do
        [] -> "No captions available"
        captions -> Enum.join(captions, " ... ")
      end
    else
      "No frames selected"
    end
  end
end