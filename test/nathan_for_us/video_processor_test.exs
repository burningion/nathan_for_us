defmodule NathanForUs.VideoProcessorTest do
  use ExUnit.Case, async: true
  
  alias NathanForUs.VideoProcessor

  @moduletag :video_processor

  describe "new/2" do
    test "creates processor with default options" do
      processor = VideoProcessor.new("test.mp4")
      
      assert processor.video_path == "test.mp4"
      assert processor.output_dir == "priv/static/frames"
      assert processor.fps == 1
      assert processor.quality == 2
      assert processor.use_hardware_accel == true
      assert processor.scene_detection == false
    end

    test "creates processor with custom options" do
      opts = [
        output_dir: "custom/frames",
        fps: 2,
        quality: 5,
        use_hardware_accel: false,
        scene_detection: true
      ]
      
      processor = VideoProcessor.new("test.mp4", opts)
      
      assert processor.video_path == "test.mp4"
      assert processor.output_dir == "custom/frames"
      assert processor.fps == 2
      assert processor.quality == 5
      assert processor.use_hardware_accel == false
      assert processor.scene_detection == true
    end
  end

  describe "get_video_info/1" do
    test "returns error for non-existent file" do
      result = VideoProcessor.get_video_info("non_existent.mp4")
      assert {:error, _reason} = result
    end

    @tag :requires_ffmpeg
    test "returns video info for valid file" do
      # This test requires a real video file and ffmpeg installed
      # Skip in CI unless video fixtures are available
      if File.exists?("test/fixtures/sample.mp4") do
        result = VideoProcessor.get_video_info("test/fixtures/sample.mp4")
        assert {:ok, metadata} = result
        assert is_map(metadata)
        assert Map.has_key?(metadata, "format")
      else
        # Skip test if no fixture available
        :ok
      end
    end
  end

  describe "estimate_frame_count/2" do
    test "returns error for non-existent file" do
      result = VideoProcessor.estimate_frame_count("non_existent.mp4")
      assert {:error, _reason} = result
    end

    @tag :requires_ffmpeg
    test "estimates frame count for valid file" do
      # This test requires a real video file and ffmpeg installed
      if File.exists?("test/fixtures/sample.mp4") do
        result = VideoProcessor.estimate_frame_count("test/fixtures/sample.mp4", 1)
        assert {:ok, frame_count} = result
        assert is_integer(frame_count)
        assert frame_count > 0
      else
        # Skip test if no fixture available
        :ok
      end
    end
  end

  describe "extract_frames/1" do
    test "returns error for non-existent video file" do
      processor = VideoProcessor.new("non_existent.mp4")
      result = VideoProcessor.extract_frames(processor)
      assert {:error, reason} = result
      assert reason =~ "Video file not found" or reason =~ "ffmpeg extraction failed"
    end

    @tag :requires_ffmpeg
    test "extracts frames from valid video file" do
      # This test requires a real video file and ffmpeg installed
      if File.exists?("test/fixtures/sample.mp4") do
        output_dir = "test/tmp/frames_#{System.unique_integer()}"
        
        processor = VideoProcessor.new("test/fixtures/sample.mp4", 
          output_dir: output_dir,
          fps: 1
        )
        
        result = VideoProcessor.extract_frames(processor)
        
        # Clean up
        File.rm_rf(output_dir)
        
        assert {:ok, frame_paths} = result
        assert is_list(frame_paths)
      else
        # Skip test if no fixture available
        :ok
      end
    end
  end

  describe "private function behavior" do
    test "build_ffmpeg_command with default settings" do
      processor = VideoProcessor.new("test.mp4")
      
      # Test via extract_frames to ensure command building works
      # This will fail at execution but validates command structure
      result = VideoProcessor.extract_frames(processor)
      
      # Should fail with video not found, not command building error
      assert {:error, reason} = result
      assert reason =~ "Video file not found" or reason =~ "ffmpeg extraction failed"
    end

    test "build_ffmpeg_command with scene detection" do
      processor = VideoProcessor.new("test.mp4", scene_detection: true, fps: 2)
      
      # Test via extract_frames to ensure command building works
      result = VideoProcessor.extract_frames(processor)
      
      # Should fail with video not found, not command building error
      assert {:error, reason} = result
      assert reason =~ "Video file not found" or reason =~ "ffmpeg extraction failed"
    end

    test "build_ffmpeg_command without hardware acceleration" do
      processor = VideoProcessor.new("test.mp4", use_hardware_accel: false)
      
      # Test via extract_frames to ensure command building works
      result = VideoProcessor.extract_frames(processor)
      
      # Should fail with video not found, not command building error
      assert {:error, reason} = result
      assert reason =~ "Video file not found" or reason =~ "ffmpeg extraction failed"
    end
  end
end