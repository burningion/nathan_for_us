defmodule NathanForUsWeb.AdminVideoUploadLive do
  use NathanForUsWeb, :live_view

  alias NathanForUs.{Video, VideoProcessor}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Admin Video Upload")
      |> assign(:uploaded_files, [])
      |> assign(:processing_status, nil)
      |> assign(:processing_progress, 0)
      |> assign(:error_message, nil)
      |> assign(:success_message, nil)
      |> assign(:video_title, "")
      |> assign(:video_description, "")
      |> allow_upload(:video,
        accept: ~w(.mp4 .mov .avi .mkv),
        max_entries: 1,
        # 5GB
        max_file_size: 5_000_000_000
      )
      |> allow_upload(:captions,
        accept: ~w(.srt .vtt),
        max_entries: 1,
        # 10MB
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"video_upload" => params}, socket) do
    socket =
      socket
      |> assign(:video_title, Map.get(params, "title", ""))
      |> assign(:video_description, Map.get(params, "description", ""))

    {:noreply, socket}
  end

  @impl true
  def handle_event("upload", %{"video_upload" => params}, socket) do
    video_title = Map.get(params, "title", "")
    video_description = Map.get(params, "description", "")

    # Validate required fields
    cond do
      video_title == "" ->
        socket = assign(socket, :error_message, "Video title is required")
        {:noreply, socket}

      socket.assigns.uploads.video.entries == [] ->
        socket = assign(socket, :error_message, "Video file is required")
        {:noreply, socket}

      socket.assigns.uploads.captions.entries == [] ->
        socket = assign(socket, :error_message, "Caption file is required")
        {:noreply, socket}

      true ->
        # Start processing
        send(self(), {:start_processing, video_title, video_description})

        socket =
          socket
          |> assign(:processing_status, "Starting upload...")
          |> assign(:processing_progress, 0)
          |> assign(:error_message, nil)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :video, ref)}
  end

  @impl true
  def handle_event("cancel-caption-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :captions, ref)}
  end

  @impl true
  def handle_info({:start_processing, title, description}, socket) do
    # Process uploads in a task to avoid blocking the LiveView
    task =
      Task.async(fn ->
        process_video_upload(socket, title, description)
      end)

    socket = assign(socket, :processing_task, task)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:processing_update, status, progress}, socket) do
    socket =
      socket
      |> assign(:processing_status, status)
      |> assign(:processing_progress, progress)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:processing_complete, result}, socket) do
    case result do
      {:ok, video} ->
        socket =
          socket
          |> assign(:processing_status, "Complete!")
          |> assign(:processing_progress, 100)
          |> assign(
            :success_message,
            "Video '#{video.title}' uploaded and processed successfully!"
          )
          |> assign(:error_message, nil)
          |> reset_form()

        {:noreply, socket}

      {:error, error} ->
        socket =
          socket
          |> assign(:processing_status, nil)
          |> assign(:processing_progress, 0)
          |> assign(:error_message, "Processing failed: #{error}")
          |> assign(:success_message, nil)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({ref, result}, socket) when is_reference(ref) do
    # Handle task completion
    Process.demonitor(ref, [:flush])
    send(self(), {:processing_complete, result})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Task crashed
    socket =
      socket
      |> assign(:processing_status, nil)
      |> assign(:processing_progress, 0)
      |> assign(:error_message, "Processing failed unexpectedly")

    {:noreply, socket}
  end

  defp process_video_upload(socket, title, description) do
    try do
      # Save uploaded files
      send(self(), {:processing_update, "Saving uploaded files...", 10})

      video_file_path = save_upload_file(socket, :video)
      caption_file_path = save_upload_file(socket, :captions)

      send(self(), {:processing_update, "Creating video record...", 20})

      # Create video record
      video_params = %{
        title: title,
        description: description,
        file_path: video_file_path,
        status: "processing"
      }

      {:ok, video} = Video.create_video(video_params)

      send(self(), {:processing_update, "Processing video frames...", 30})

      # Process video using VideoProcessor
      case VideoProcessor.process_video_with_captions(
             video.id,
             video_file_path,
             caption_file_path
           ) do
        {:ok, _result} ->
          send(self(), {:processing_update, "Finalizing...", 90})

          # Update video status
          Video.update_video(video, %{status: "completed"})

          {:ok, video}

        {:error, reason} ->
          # Update video status to failed
          Video.update_video(video, %{status: "failed"})
          {:error, reason}
      end
    rescue
      error ->
        {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  defp save_upload_file(socket, upload_key) do
    [entry] = socket.assigns.uploads[upload_key].entries

    # Create uploads directory if it doesn't exist
    upload_dir = Path.join([Application.app_dir(:nathan_for_us, "priv"), "uploads"])
    File.mkdir_p!(upload_dir)

    # Generate unique filename
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    filename = "#{timestamp}_#{entry.client_name}"
    file_path = Path.join(upload_dir, filename)

    # Consume upload and save file
    consume_uploaded_entry(socket, entry, fn %{path: temp_path} ->
      File.cp!(temp_path, file_path)
      {:ok, file_path}
    end)
  end

  defp reset_form(socket) do
    socket
    |> assign(:video_title, "")
    |> assign(:video_description, "")
    |> assign(:uploaded_files, [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <div class="container mx-auto px-4 py-8">
        <div class="max-w-4xl mx-auto">
          <h1 class="text-3xl font-bold mb-8 text-center">Admin Video Upload</h1>

          <%= if @error_message do %>
            <div class="bg-red-600 text-white p-4 rounded-lg mb-6">
              <p>{@error_message}</p>
            </div>
          <% end %>

          <%= if @success_message do %>
            <div class="bg-green-600 text-white p-4 rounded-lg mb-6">
              <p>{@success_message}</p>
            </div>
          <% end %>

          <%= if @processing_status do %>
            <div class="bg-blue-600 text-white p-4 rounded-lg mb-6">
              <p class="mb-2">{@processing_status}</p>
              <div class="w-full bg-blue-800 rounded-full h-2">
                <div
                  class="bg-blue-400 h-2 rounded-full transition-all duration-300"
                  style={"width: #{@processing_progress}%"}
                >
                </div>
              </div>
              <p class="text-sm mt-1">{@processing_progress}% complete</p>
            </div>
          <% end %>

          <form phx-submit="upload" phx-change="validate" class="space-y-6">
            <div class="bg-gray-800 p-6 rounded-lg">
              <h2 class="text-xl font-semibold mb-4">Video Details</h2>

              <div class="space-y-4">
                <div>
                  <label for="title" class="block text-sm font-medium mb-2">Video Title *</label>
                  <input
                    type="text"
                    name="video_upload[title]"
                    id="title"
                    value={@video_title}
                    class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Enter video title"
                    required
                  />
                </div>

                <div>
                  <label for="description" class="block text-sm font-medium mb-2">Description</label>
                  <textarea
                    name="video_upload[description]"
                    id="description"
                    rows="3"
                    class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Enter video description"
                  ><%= @video_description %></textarea>
                </div>
              </div>
            </div>

            <div class="grid md:grid-cols-2 gap-6">
              <!-- Video Upload -->
              <div class="bg-gray-800 p-6 rounded-lg">
                <h3 class="text-lg font-semibold mb-4">Video File *</h3>

                <div
                  class="border-2 border-dashed border-gray-600 rounded-lg p-6 text-center hover:border-gray-500 transition-colors"
                  phx-drop-target={@uploads.video.ref}
                >
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400 mb-4"
                    stroke="currentColor"
                    fill="none"
                    viewBox="0 0 48 48"
                  >
                    <path
                      d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>

                  <label for={@uploads.video.ref} class="cursor-pointer">
                    <span class="text-blue-400 hover:text-blue-300">Upload video file</span>
                    <span class="text-gray-400"> or drag and drop</span>
                  </label>

                  <p class="text-xs text-gray-500 mt-2">MP4, MOV, AVI, MKV up to 5GB</p>

                  <.live_file_input upload={@uploads.video} class="sr-only" />
                </div>

                <%= for entry <- @uploads.video.entries do %>
                  <div class="mt-4 p-3 bg-gray-700 rounded-lg flex items-center justify-between">
                    <div>
                      <p class="text-sm font-medium">{entry.client_name}</p>
                      <p class="text-xs text-gray-400">{format_file_size(entry.client_size)}</p>
                    </div>
                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      class="text-red-400 hover:text-red-300"
                    >
                      ✕
                    </button>
                  </div>
                <% end %>
              </div>
              
    <!-- Caption Upload -->
              <div class="bg-gray-800 p-6 rounded-lg">
                <h3 class="text-lg font-semibold mb-4">Caption File *</h3>

                <div
                  class="border-2 border-dashed border-gray-600 rounded-lg p-6 text-center hover:border-gray-500 transition-colors"
                  phx-drop-target={@uploads.captions.ref}
                >
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400 mb-4"
                    stroke="currentColor"
                    fill="none"
                    viewBox="0 0 48 48"
                  >
                    <path
                      d="M9 12h6m6 0h6m-6 6h6m-12 6h12M9 24h6"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>

                  <label for={@uploads.captions.ref} class="cursor-pointer">
                    <span class="text-blue-400 hover:text-blue-300">Upload caption file</span>
                    <span class="text-gray-400"> or drag and drop</span>
                  </label>

                  <p class="text-xs text-gray-500 mt-2">SRT, VTT up to 10MB</p>

                  <.live_file_input upload={@uploads.captions} class="sr-only" />
                </div>

                <%= for entry <- @uploads.captions.entries do %>
                  <div class="mt-4 p-3 bg-gray-700 rounded-lg flex items-center justify-between">
                    <div>
                      <p class="text-sm font-medium">{entry.client_name}</p>
                      <p class="text-xs text-gray-400">{format_file_size(entry.client_size)}</p>
                    </div>
                    <button
                      type="button"
                      phx-click="cancel-caption-upload"
                      phx-value-ref={entry.ref}
                      class="text-red-400 hover:text-red-300"
                    >
                      ✕
                    </button>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="flex justify-center">
              <button
                type="submit"
                disabled={@processing_status != nil}
                class="px-8 py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors"
              >
                <%= if @processing_status do %>
                  Processing...
                <% else %>
                  Upload and Process Video
                <% end %>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp format_file_size(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end
end
