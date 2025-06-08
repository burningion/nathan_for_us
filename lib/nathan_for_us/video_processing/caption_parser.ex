defmodule NathanForUs.VideoProcessing.CaptionParser do
  @moduledoc """
  GenStage producer-consumer that parses SRT caption files.
  
  Takes frame extraction results and looks for corresponding SRT files,
  parses them, and combines the data for database storage.
  """
  
  use GenStage
  require Logger
  
  alias NathanForUs.SrtParser

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Caption parser starting")
    
    {:producer_consumer, %{},
     subscribe_to: [
       {NathanForUs.VideoProcessing.FrameExtractor, min_demand: 1, max_demand: 2}
     ]}
  end

  @impl true
  def handle_events(frame_events, _from, state) do
    Logger.info("Caption parser received #{length(frame_events)} frame events")
    
    events = 
      frame_events
      |> Enum.map(&parse_captions_for_video/1)
      |> Enum.reject(&is_nil/1)
    
    {:noreply, events, state}
  end

  defp parse_captions_for_video(%{video: video} = frame_event) do
    Logger.info("Looking for captions for video: #{video.title}")
    
    # Look for SRT file with same base name as video
    video_dir = Path.dirname(video.file_path)
    video_basename = Path.basename(video.file_path, Path.extname(video.file_path))
    
    srt_patterns = [
      Path.join(video_dir, "#{video_basename}.srt"),
      Path.join(video_dir, "#{video_basename}.en.srt"),
      # Handle the format we have in vid/ directory
      video.file_path |> String.replace(Path.extname(video.file_path), ".en.srt")
    ]
    
    srt_file = Enum.find(srt_patterns, &File.exists?/1)
    
    if srt_file do
      Logger.info("Found caption file: #{srt_file}")
      parse_srt_file(frame_event, srt_file)
    else
      Logger.warn("No caption file found for #{video.title}, proceeding without captions")
      Map.put(frame_event, :caption_data, [])
    end
  end

  defp parse_srt_file(frame_event, srt_file) do
    case SrtParser.parse_file(srt_file) do
      {:ok, subtitle_entries} ->
        Logger.info("Parsed #{length(subtitle_entries)} subtitle entries")
        
        # Convert SRT entries to database format
        caption_data = 
          subtitle_entries
          |> Enum.map(fn entry ->
            %{
              start_time_ms: entry.start_time,
              end_time_ms: entry.end_time, 
              text: entry.text,
              caption_index: entry.index
            }
          end)
        
        Map.put(frame_event, :caption_data, caption_data)
        
      {:error, reason} ->
        Logger.error("Failed to parse SRT file #{srt_file}: #{reason}")
        Map.put(frame_event, :caption_data, [])
    end
  end
end