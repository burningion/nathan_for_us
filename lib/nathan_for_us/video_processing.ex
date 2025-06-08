defmodule NathanForUs.VideoProcessing do
  @moduledoc """
  GenStage-based video processing pipeline for extracting frames and parsing captions.
  
  The pipeline consists of:
  1. Producer - Monitors for new videos to process
  2. FrameExtractor - Extracts frames using ffmpeg  
  3. CaptionParser - Parses SRT files
  4. DatabaseConsumer - Saves results to database and links frames to captions
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Producer that monitors for videos to process
      {NathanForUs.VideoProcessing.Producer, []},
      
      # Frame extraction stage
      {NathanForUs.VideoProcessing.FrameExtractor, []},
      
      # Caption parsing stage  
      {NathanForUs.VideoProcessing.CaptionParser, []},
      
      # Database consumer that saves everything
      {NathanForUs.VideoProcessing.DatabaseConsumer, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Queue a video for processing.
  """
  def process_video(video_path, title \\ nil) do
    NathanForUs.VideoProcessing.Producer.queue_video(video_path, title)
  end

  @doc """
  Get processing status for all videos.
  """
  def get_processing_status do
    NathanForUs.Video.list_videos()
  end
end