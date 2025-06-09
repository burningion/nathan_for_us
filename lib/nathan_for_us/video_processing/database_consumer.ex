defmodule NathanForUs.VideoProcessing.DatabaseConsumer do
  @moduledoc """
  GenStage consumer that saves processed video data to the database.
  
  Takes combined frame and caption data and saves it to the database,
  then links frames to captions based on timestamp overlap.
  """
  
  use GenStage
  require Logger
  
  alias NathanForUs.{Video, Repo}

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Database consumer starting")
    
    {:consumer, %{},
     subscribe_to: [
       {NathanForUs.VideoProcessing.CaptionParser, min_demand: 1, max_demand: 2}
     ]}
  end

  @impl true
  def handle_events(processing_events, _from, state) do
    Logger.info("Database consumer received #{length(processing_events)} processing events")
    
    for event <- processing_events do
      process_event(event)
    end
    
    {:noreply, [], state}
  end

  defp process_event(%{video: video} = event) do
    Logger.info("Processing event for video: #{video.title}")
    
    case save_video_data(event) do
      {:ok, _result} ->
        Logger.info("Successfully processed video: #{video.title}")
        mark_video_completed(video)
      
      {:error, reason} ->
        Logger.error("Failed to process video #{video.title}: #{reason}")
        mark_video_failed(video)
    end
  end

  defp save_video_data(%{video: video, frame_data: frame_data, caption_data: caption_data}) do
    Repo.transaction(fn ->
      with {:ok, _frames} <- save_frames(video.id, frame_data),
           {:ok, _captions} <- save_captions(video.id, caption_data),
           {:ok, _links} <- link_frames_to_captions(video.id, caption_data) do
        :ok
      else
        {:error, reason} ->
          Logger.error("Database operation failed: #{reason}")
          Repo.rollback(reason)
      end
    end)
  end

  defp save_frames(video_id, frame_data) when length(frame_data) > 0 do
    Logger.info("Saving #{length(frame_data)} frames")
    
    case Video.create_frames_batch(video_id, frame_data) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, "Failed to save frames: #{reason}"}
    end
  end
  defp save_frames(_video_id, []), do: {:ok, []}

  defp save_captions(video_id, caption_data) when length(caption_data) > 0 do
    Logger.info("Saving #{length(caption_data)} captions")
    
    case Video.create_captions_batch(video_id, caption_data) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, "Failed to save captions: #{reason}"}
    end
  end
  defp save_captions(_video_id, []), do: {:ok, []}

  defp link_frames_to_captions(video_id, caption_data) when length(caption_data) > 0 do
    Logger.info("Linking frames to captions")
    
    case Video.link_frames_to_captions(video_id) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, "Failed to link frames to captions: #{reason}"}
    end
  end
  defp link_frames_to_captions(_video_id, []), do: {:ok, []}

  defp mark_video_completed(video) do
    Video.update_video(video, %{
      status: "completed",
      completed_at: DateTime.utc_now()
    })
  end

  defp mark_video_failed(video) do
    Video.update_video(video, %{
      status: "failed",
      completed_at: DateTime.utc_now()
    })
  end
end