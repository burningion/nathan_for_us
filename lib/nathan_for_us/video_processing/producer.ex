defmodule NathanForUs.VideoProcessing.Producer do
  @moduledoc """
  GenStage producer that monitors for videos to process.

  This producer looks for videos with status "pending" and emits them
  as events for downstream processing stages.
  """

  use GenStage
  require Logger

  alias NathanForUs.Video

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def queue_video(video_path, title \\ nil) do
    title = title || Path.basename(video_path, Path.extname(video_path))

    attrs = %{
      title: title,
      file_path: video_path,
      status: "pending"
    }

    case Video.create_video(attrs) do
      {:ok, video} ->
        Logger.info("Queued video for processing: #{video.title}")
        # Notify producer to check for new work
        send(__MODULE__, :check_for_videos)
        {:ok, video}

      {:error, changeset} ->
        Logger.error("Failed to queue video: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @impl true
  def init(_opts) do
    Logger.info("Video processing producer starting")

    # Schedule periodic checks for new videos
    schedule_check()

    {:producer, %{}, dispatcher: GenStage.DemandDispatcher}
  end

  @impl true
  def handle_demand(demand, state) when demand > 0 do
    Logger.debug("Producer received demand for #{demand} videos")

    videos = fetch_pending_videos(demand)

    if length(videos) > 0 do
      Logger.info("Fetched #{length(videos)} pending videos")
      mark_videos_as_processing(videos)
      {:noreply, videos, state}
    else
      Logger.debug("No pending videos found")
      {:noreply, [], state}
    end
  end

  @impl true
  def handle_info(:check_for_videos, state) do
    # Check for new videos even when there's no pending demand
    videos = fetch_pending_videos(10)

    if length(videos) > 0 do
      mark_videos_as_processing(videos)
      {:noreply, videos, state}
    else
      schedule_check()
      {:noreply, [], state}
    end
  end

  defp fetch_pending_videos(limit) do
    Video.list_videos_by_status("pending")
    |> Enum.take(limit)
  end

  defp mark_videos_as_processing(videos) do
    for video <- videos do
      Video.update_video(video, %{
        status: "processing",
        processed_at: DateTime.utc_now()
      })
    end
  end

  defp schedule_check do
    # Check every 5 seconds
    Process.send_after(self(), :check_for_videos, 5000)
  end
end
