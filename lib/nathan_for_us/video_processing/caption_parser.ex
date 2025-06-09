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
  def init(_opts) do
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
      |> Enum.map(&process_captions/1)
      |> Enum.reject(&is_nil/1)
    
    {:noreply, events, state}
  end

  defp process_captions(%{video: video} = frame_event) do
    Logger.info("Processing captions for video: #{video.title}")
    
    case find_caption_file(video) do
      {:ok, srt_file} ->
        Logger.info("Found caption file: #{srt_file}")
        parse_and_attach_captions(frame_event, srt_file)
      
      {:error, :not_found} ->
        Logger.warning("No caption file found for #{video.title}, proceeding without captions")
        attach_empty_captions(frame_event)
    end
  end
  
  defp find_caption_file(%{file_path: file_path}) do
    video_dir = Path.dirname(file_path)
    video_basename = Path.basename(file_path, Path.extname(file_path))
    
    srt_patterns = build_srt_patterns(video_dir, video_basename, file_path)
    
    case Enum.find(srt_patterns, &File.exists?/1) do
      nil -> {:error, :not_found}
      srt_file -> {:ok, srt_file}
    end
  end
  
  defp build_srt_patterns(video_dir, video_basename, file_path) do
    [
      Path.join(video_dir, "#{video_basename}.srt"),
      Path.join(video_dir, "#{video_basename}.en.srt"),
      String.replace(file_path, Path.extname(file_path), ".en.srt")
    ]
  end
  
  defp parse_and_attach_captions(frame_event, srt_file) do
    case parse_srt_file(srt_file) do
      {:ok, caption_data} ->
        Map.put(frame_event, :caption_data, caption_data)
      
      {:error, reason} ->
        Logger.error("Failed to parse SRT file #{srt_file}: #{reason}")
        attach_empty_captions(frame_event)
    end
  end
  
  defp attach_empty_captions(frame_event) do
    Map.put(frame_event, :caption_data, [])
  end

  defp parse_srt_file(srt_file) do
    case SrtParser.parse_file(srt_file) do
      {:ok, subtitle_entries} ->
        Logger.info("Parsed #{length(subtitle_entries)} subtitle entries")
        caption_data = convert_to_database_format(subtitle_entries)
        {:ok, caption_data}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp convert_to_database_format(subtitle_entries) do
    Enum.map(subtitle_entries, fn entry ->
      %{
        start_time_ms: entry.start_time,
        end_time_ms: entry.end_time,
        text: entry.text,
        caption_index: entry.index
      }
    end)
  end
end