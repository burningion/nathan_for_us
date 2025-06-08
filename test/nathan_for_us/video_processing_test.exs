defmodule NathanForUs.VideoProcessingTest do
  use NathanForUs.DataCase, async: false
  
  alias NathanForUs.{VideoProcessing, Video, Repo}
  alias NathanForUs.Video.{VideoFrame, VideoCaption}

  @moduletag :video_processing

  describe "video processing pipeline" do
    test "queues video for processing" do
      video_path = "test/fixtures/sample.mp4"
      
      # Skip if no fixture available
      if File.exists?(video_path) do
        {:ok, video} = VideoProcessing.process_video(video_path, "Test Video")
        
        assert video.title == "Test Video"
        assert video.file_path == video_path
        assert video.status == "pending"
      else
        # Test just the queuing logic without actual file
        video_path = "vid/The Obscure World of Model Train Synthesizers [wfu6wGAp83o].mp4"
        
        if File.exists?(video_path) do
          {:ok, video} = VideoProcessing.process_video(video_path)
          
          assert video.title == "The Obscure World of Model Train Synthesizers [wfu6wGAp83o]"
          assert video.file_path == video_path
          assert video.status == "pending"
        else
          # Skip test if no video available
          :ok
        end
      end
    end

    test "handles duplicate video paths" do
      video_path = "test/fixtures/duplicate.mp4"
      
      # Create first video
      {:ok, _video1} = Video.create_video(%{
        title: "First Video",
        file_path: video_path
      })
      
      # Try to create duplicate
      result = VideoProcessing.process_video(video_path, "Duplicate Video")
      
      assert {:error, changeset} = result
      assert changeset.errors[:file_path]
    end

    test "gets processing status" do
      # Create test videos with different statuses
      {:ok, _pending} = Video.create_video(%{
        title: "Pending Video",
        file_path: "test/pending.mp4",
        status: "pending"
      })
      
      {:ok, _completed} = Video.create_video(%{
        title: "Completed Video", 
        file_path: "test/completed.mp4",
        status: "completed"
      })
      
      status = VideoProcessing.get_processing_status()
      
      assert length(status) >= 2
      assert Enum.any?(status, &(&1.status == "pending"))
      assert Enum.any?(status, &(&1.status == "completed"))
    end
  end

  describe "video context" do
    test "creates video with valid attributes" do
      attrs = %{
        title: "Test Video",
        file_path: "test/video.mp4",
        status: "pending"
      }
      
      {:ok, video} = Video.create_video(attrs)
      
      assert video.title == "Test Video"
      assert video.file_path == "test/video.mp4"
      assert video.status == "pending"
    end

    test "validates required fields" do
      attrs = %{status: "pending"}
      
      {:error, changeset} = Video.create_video(attrs)
      
      assert changeset.errors[:title]
      assert changeset.errors[:file_path]
    end

    test "creates frames in batch" do
      {:ok, video} = Video.create_video(%{
        title: "Test Video",
        file_path: "test/video.mp4"
      })
      
      frame_data = [
        %{frame_number: 0, timestamp_ms: 0, file_path: "frame_0.jpg"},
        %{frame_number: 1, timestamp_ms: 1000, file_path: "frame_1.jpg"},
        %{frame_number: 2, timestamp_ms: 2000, file_path: "frame_2.jpg"}
      ]
      
      {count, _} = Video.create_frames_batch(video.id, frame_data)
      
      assert count == 3
      
      frames = Repo.all(VideoFrame)
      assert length(frames) == 3
    end

    test "creates captions in batch" do
      {:ok, video} = Video.create_video(%{
        title: "Test Video",
        file_path: "test/video.mp4"
      })
      
      caption_data = [
        %{start_time_ms: 0, end_time_ms: 2000, text: "First caption", caption_index: 1},
        %{start_time_ms: 2000, end_time_ms: 4000, text: "Second caption", caption_index: 2}
      ]
      
      {count, _} = Video.create_captions_batch(video.id, caption_data)
      
      assert count == 2
      
      captions = Repo.all(VideoCaption)
      assert length(captions) == 2
    end

    test "links frames to captions based on timestamp overlap" do
      {:ok, video} = Video.create_video(%{
        title: "Test Video",
        file_path: "test/video.mp4"
      })
      
      # Create frames
      frame_data = [
        %{frame_number: 0, timestamp_ms: 500, file_path: "frame_0.jpg"},
        %{frame_number: 1, timestamp_ms: 1500, file_path: "frame_1.jpg"},
        %{frame_number: 2, timestamp_ms: 2500, file_path: "frame_2.jpg"}
      ]
      Video.create_frames_batch(video.id, frame_data)
      
      # Create captions
      caption_data = [
        %{start_time_ms: 0, end_time_ms: 1000, text: "First caption", caption_index: 1},
        %{start_time_ms: 1000, end_time_ms: 2000, text: "Second caption", caption_index: 2},
        %{start_time_ms: 2000, end_time_ms: 3000, text: "Third caption", caption_index: 3}
      ]
      Video.create_captions_batch(video.id, caption_data)
      
      # Link frames to captions
      {link_count, _} = Video.link_frames_to_captions(video.id)
      
      # Frame 0 (500ms) should link to caption 1 (0-1000ms)
      # Frame 1 (1500ms) should link to caption 2 (1000-2000ms)  
      # Frame 2 (2500ms) should link to caption 3 (2000-3000ms)
      assert link_count == 3
    end

    test "searches frames by text" do
      {:ok, video} = Video.create_video(%{
        title: "Test Video",
        file_path: "test/video.mp4"
      })
      
      # Create frames
      frame_data = [
        %{frame_number: 0, timestamp_ms: 500, file_path: "frame_0.jpg"},
        %{frame_number: 1, timestamp_ms: 1500, file_path: "frame_1.jpg"}
      ]
      Video.create_frames_batch(video.id, frame_data)
      
      # Create captions
      caption_data = [
        %{start_time_ms: 0, end_time_ms: 1000, text: "choo choo train sounds", caption_index: 1},
        %{start_time_ms: 1000, end_time_ms: 2000, text: "bird chirping", caption_index: 2}
      ]
      Video.create_captions_batch(video.id, caption_data)
      
      # Link frames to captions
      Video.link_frames_to_captions(video.id)
      
      # Search for "choo choo" - should find frame 0
      results = Video.search_frames_by_text_simple("choo choo")
      
      assert length(results) == 1
      assert hd(results).frame_number == 0
      
      # Search for "bird" - should find frame 1
      results = Video.search_frames_by_text_simple("bird")
      
      assert length(results) == 1
      assert hd(results).frame_number == 1
    end
  end
end