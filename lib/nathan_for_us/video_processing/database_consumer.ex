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
  def init(opts) do
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
      save_video_data(event)
    end
    
    {:noreply, [], state}
  end

  defp save_video_data(%{video: video, frame_data: frame_data, caption_data: caption_data}) do
    Logger.info("Saving data for video: #{video.title}")
    
    Repo.transaction(fn ->
      try do
        # Save frames in batch
        if length(frame_data) > 0 do
          Logger.info("Saving #{length(frame_data)} frames")
          Video.create_frames_batch(video.id, frame_data)
        end
        
        # Save captions in batch
        if length(caption_data) > 0 do
          Logger.info("Saving #{length(caption_data)} captions")
          Video.create_captions_batch(video.id, caption_data)
          
          # Link frames to captions based on timestamp overlap
          Logger.info("Linking frames to captions")
          Video.link_frames_to_captions(video.id)
        end
        
        # Mark video as completed
        Video.update_video(video, %{
          status: "completed",
          completed_at: DateTime.utc_now()
        })
        
        Logger.info("Successfully processed video: #{video.title}")
        
      rescue
        error ->
          Logger.error("Failed to save video data: #{Exception.format(:error, error, __STACKTRACE__)}")
          
          Video.update_video(video, %{
            status: "failed",
            completed_at: DateTime.utc_now()
          })
          
          Repo.rollback(error)
      end
    end)
  end
end