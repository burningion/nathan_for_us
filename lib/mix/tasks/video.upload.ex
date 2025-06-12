defmodule Mix.Tasks.Video.Upload do
  @moduledoc """
  Uploads processed video data from local database to production.
  
  This task extracts video data (video record, frames, and captions) from the local 
  database and uploads it to the production server via the API endpoint.
  
  Usage:
    mix video.upload --video-id=16 --api-url=https://your-prod-app.com
    mix video.upload --video-id=16 --api-url=https://your-prod-app.com --batch-size=100
  
  Options:
    --video-id      ID of the video to upload (required)
    --api-url       Production API base URL (required)
    --batch-size    Number of frames to send per batch (default: 50)
    --dry-run       Show what would be uploaded without actually sending (default: false)
  """
  
  use Mix.Task
  import Ecto.Query, warn: false
  
  alias NathanForUs.Repo
  alias NathanForUs.Video
  alias NathanForUs.Video.{VideoFrame, VideoCaption}
  
  @shortdoc "Upload video data to production"
  
  def run(args) do
    {opts, _} = OptionParser.parse!(args, 
      strict: [
        video_id: :integer,
        api_url: :string,
        batch_size: :integer,
        dry_run: :boolean
      ]
    )
    
    video_id = opts[:video_id] || raise_missing_option("video-id")
    api_url = opts[:api_url] || raise_missing_option("api-url")
    batch_size = opts[:batch_size] || 10
    dry_run = opts[:dry_run] || false
    
    IO.puts("🗄️  Starting video data upload process...")
    
    # Start the application to access the database
    Mix.Task.run("app.start")
    
    case extract_video_data(video_id) do
      {:ok, video_data} ->
        if dry_run do
          show_upload_preview(video_data)
        else
          upload_video_data(video_data, api_url, batch_size)
        end
        
      {:error, :video_not_found} ->
        IO.puts("❌ Video with ID #{video_id} not found in local database")
        System.halt(1)
        
      {:error, reason} ->
        IO.puts("❌ Failed to extract video data: #{reason}")
        System.halt(1)
    end
  end
  
  defp raise_missing_option(option) do
    raise "Missing required option: --#{option}. Run 'mix help video.upload' for usage."
  end
  
  defp extract_video_data(video_id) do
    IO.puts("📊 Extracting video data for ID #{video_id}...")
    
    case Video.get_video(video_id) do
      {:ok, video} ->
        IO.puts("   ✅ Found video: #{video.title}")
        
        # Get all frames with image data
        frames = get_video_frames_with_data(video_id)
        IO.puts("   📸 Extracted #{length(frames)} frames with image data")
        
        # Get all captions
        captions = get_video_captions(video_id)
        IO.puts("   💬 Extracted #{length(captions)} captions")
        
        video_data = %{
          video: prepare_video_for_upload(video),
          frames: frames,
          captions: captions
        }
        
        {:ok, video_data}
        
      {:error, :not_found} ->
        {:error, :video_not_found}
    end
  end
  
  defp get_video_frames_with_data(video_id) do
    VideoFrame
    |> where([f], f.video_id == ^video_id)
    |> order_by([f], f.frame_number)
    |> Repo.all()
    |> Enum.map(fn frame ->
      %{
        frame_number: frame.frame_number,
        timestamp_ms: frame.timestamp_ms,
        file_path: frame.file_path,
        file_size: frame.file_size,
        width: frame.width,
        height: frame.height,
        image_data: encode_image_data(frame.image_data),
        compression_ratio: frame.compression_ratio
      }
    end)
  end
  
  defp get_video_captions(video_id) do
    VideoCaption
    |> where([c], c.video_id == ^video_id)
    |> order_by([c], c.start_time_ms)
    |> Repo.all()
    |> Enum.map(fn caption ->
      %{
        start_time_ms: caption.start_time_ms,
        end_time_ms: caption.end_time_ms,
        text: caption.text,
        caption_index: caption.caption_index
      }
    end)
  end
  
  defp prepare_video_for_upload(video) do
    %{
      title: video.title,
      file_path: video.file_path,
      duration_ms: video.duration_ms,
      fps: video.fps,
      frame_count: video.frame_count,
      metadata: video.metadata || %{}
    }
  end
  
  defp encode_image_data(nil), do: nil
  defp encode_image_data(binary_data), do: Base.encode64(binary_data)
  
  defp show_upload_preview(video_data) do
    IO.puts("🔍 DRY RUN - Would upload the following data:")
    IO.puts("   📹 Video: #{video_data.video.title}")
    IO.puts("   📸 Frames: #{length(video_data.frames)}")
    IO.puts("   💬 Captions: #{length(video_data.captions)}")
    
    # Calculate total payload size
    frames_with_data = Enum.count(video_data.frames, fn frame -> frame.image_data != nil end)
    IO.puts("   🗂️  Frames with image data: #{frames_with_data}")
    
    IO.puts("✅ Dry run completed - no data was actually uploaded")
  end
  
  defp upload_video_data(video_data, api_url, batch_size) do
    url = String.trim_trailing(api_url, "/") <> "/api/videos/upload"
    IO.puts("🚀 Uploading to: #{url}")
    
    # Split frames into batches to avoid huge payloads
    frame_batches = Enum.chunk_every(video_data.frames, batch_size)
    total_batches = length(frame_batches)
    
    IO.puts("📦 Splitting into #{total_batches} batches of #{batch_size} frames each")
    
    frame_batches
    |> Enum.with_index(1)
    |> Enum.each(fn {frame_batch, batch_num} ->
      upload_batch(video_data.video, video_data.captions, frame_batch, url, batch_num, total_batches)
    end)
    
    IO.puts("✅ All batches uploaded successfully!")
  end
  
  defp upload_batch(video, captions, frames, url, batch_num, total_batches) do
    IO.puts("📤 Uploading batch #{batch_num}/#{total_batches} (#{length(frames)} frames)...")
    
    payload = %{
      video: video,
      frames: frames,
      captions: if(batch_num == 1, do: captions, else: [])  # Only send captions with first batch
    }
    
    case Req.post(url, json: payload, receive_timeout: 60_000) do
      {:ok, %Req.Response{status: 201, body: body}} ->
        IO.puts("   ✅ Batch #{batch_num} uploaded successfully")
        
        if batch_num == total_batches do
          show_upload_stats(body)
        end
        
      {:ok, %Req.Response{status: status_code, body: body}} ->
        IO.puts("   ❌ Batch #{batch_num} failed with status #{status_code}")
        IO.puts("   📄 Response: #{inspect(body)}")
        System.halt(1)
        
      {:error, reason} ->
        IO.puts("   ❌ Network error uploading batch #{batch_num}: #{inspect(reason)}")
        System.halt(1)
    end
  end
  
  defp show_upload_stats(response) do
    IO.puts("📊 Upload Statistics:")
    
    if response["stats"] do
      stats = response["stats"]
      IO.puts("   📸 Frames uploaded: #{stats["frame_count"]}")
      IO.puts("   💬 Captions uploaded: #{stats["caption_count"]}")
      IO.puts("   🔗 Frame-caption links: #{stats["frame_caption_links"]}")
    end
    
    if response["video_id"] do
      IO.puts("   🆔 Production video ID: #{response["video_id"]}")
    end
  end
end