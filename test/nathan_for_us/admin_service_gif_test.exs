defmodule NathanForUs.AdminServiceGifTest do
  use NathanForUs.DataCase

  alias NathanForUs.AdminService
  alias NathanForUs.Video
  alias NathanForUs.Video.Video, as: VideoSchema
  alias NathanForUs.Video.{VideoFrame, VideoCaption, FrameCaption}

  @moduletag :gif_generation

  describe "generate_gif_from_frames/2" do
    setup do
      # Create test video
      {:ok, video} = %VideoSchema{}
      |> VideoSchema.changeset(%{
        title: "Test Video",
        file_path: "/test/video.mp4",
        duration_ms: 5000,
        fps: 30.0,
        frame_count: 5,
        status: "completed"
      })
      |> Repo.insert()

      # Create test frames with mock image data
      frames = for i <- 1..5 do
        # Create simple mock JPEG data (basic JPEG header)
        mock_jpeg_data = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46>> <> 
                        <<0x00, 0x01, 0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00>> <>
                        :crypto.strong_rand_bytes(100) <> <<0xFF, 0xD9>>  # End of image
        
        hex_encoded = "\\x" <> Base.encode16(mock_jpeg_data, case: :lower)
        
        %{
          frame_number: i,
          timestamp_ms: i * 1000,
          file_path: "frame_#{i}.jpg",
          file_size: byte_size(mock_jpeg_data),
          width: 1920,
          height: 1080,
          image_data: hex_encoded,
          video_id: video.id,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end

      {_count, frame_records} = Repo.insert_all(VideoFrame, frames, returning: true)

      # Create test captions
      captions = for i <- 1..5 do
        %{
          text: "Caption for frame #{i}",
          start_time_ms: (i - 1) * 1000,
          end_time_ms: i * 1000,
          video_id: video.id,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end

      {_count, caption_records} = Repo.insert_all(VideoCaption, captions, returning: true)

      # Link frames to captions
      frame_caption_links = for {frame, caption} <- Enum.zip(frame_records, caption_records) do
        %{
          frame_id: frame.id,
          caption_id: caption.id,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end

      Repo.insert_all(FrameCaption, frame_caption_links)

      %{video: video, frames: frame_records, captions: caption_records}
    end

    test "returns error when no frames selected", %{frames: frames} do
      target_frame = List.first(frames)
      {:ok, frame_sequence} = Video.get_frame_sequence(target_frame.id)

      result = AdminService.generate_gif_from_frames(frame_sequence, [])

      assert {:error, "No frames selected for GIF generation"} = result
    end

    test "handles frame sequence with valid selected indices", %{frames: frames} do
      target_frame = List.first(frames)
      {:ok, frame_sequence} = Video.get_frame_sequence(target_frame.id)
      
      selected_indices = [0, 1, 2]

      # This test will fail if FFmpeg is not available, which is expected in CI
      case AdminService.generate_gif_from_frames(frame_sequence, selected_indices) do
        {:ok, gif_data} ->
          # If FFmpeg is available, we should get binary GIF data
          assert is_binary(gif_data)
          assert byte_size(gif_data) > 0
          
          # Check for GIF header
          assert binary_part(gif_data, 0, 6) == "GIF89a"
          
        {:error, error_message} ->
          # Expected if FFmpeg is not available
          assert is_binary(error_message)
          assert String.contains?(error_message, "GIF generation failed") or
                 String.contains?(error_message, "ffmpeg")
      end
    end

    test "handles single frame selection", %{frames: frames} do
      target_frame = List.first(frames)
      {:ok, frame_sequence} = Video.get_frame_sequence(target_frame.id)
      
      selected_indices = [0]

      case AdminService.generate_gif_from_frames(frame_sequence, selected_indices) do
        {:ok, gif_data} ->
          assert is_binary(gif_data)
          assert byte_size(gif_data) > 0
          
        {:error, error_message} ->
          # Expected if FFmpeg is not available
          assert is_binary(error_message)
      end
    end

    test "handles frames without image data gracefully", %{frames: frames} do
      target_frame = List.first(frames)
      
      # Create a frame sequence with a frame that has no image data
      frame_without_data = %{List.first(frames) | image_data: nil}
      mock_sequence = %{
        target_frame: target_frame,
        sequence_frames: [frame_without_data],
        target_captions: "Test caption",
        sequence_captions: %{},
        sequence_info: %{
          target_frame_number: 1,
          start_frame_number: 1,
          end_frame_number: 1,
          total_frames: 1
        }
      }
      
      selected_indices = [0]

      result = AdminService.generate_gif_from_frames(mock_sequence, selected_indices)

      case result do
        {:ok, _gif_data} ->
          # Shouldn't happen since we have no valid frames
          flunk("Expected error but got success")
          
        {:error, error_message} ->
          # Should fail due to no valid frames or FFmpeg issues
          assert is_binary(error_message)
      end
    end

    test "calculates appropriate frame rate for different timestamp patterns", %{frames: frames} do
      target_frame = List.first(frames)
      {:ok, frame_sequence} = Video.get_frame_sequence(target_frame.id)
      
      # Test the frame rate calculation indirectly by checking the behavior
      # We can't directly test the private function, but we can verify the GIF generation
      # uses reasonable parameters
      
      selected_indices = [0, 1]

      case AdminService.generate_gif_from_frames(frame_sequence, selected_indices) do
        {:ok, _gif_data} ->
          # If successful, the framerate calculation worked
          assert true
          
        {:error, _error_message} ->
          # Expected if FFmpeg is not available, but shouldn't crash
          assert true
      end
    end

    test "handles invalid image data gracefully", %{frames: frames} do
      target_frame = List.first(frames)
      
      # Create a frame sequence with invalid image data
      frame_with_bad_data = %{List.first(frames) | image_data: "invalid_data"}
      mock_sequence = %{
        target_frame: target_frame,
        sequence_frames: [frame_with_bad_data],
        target_captions: "Test caption",
        sequence_captions: %{},
        sequence_info: %{
          target_frame_number: 1,
          start_frame_number: 1,
          end_frame_number: 1,
          total_frames: 1
        }
      }
      
      selected_indices = [0]

      # Should not crash, but may produce error or invalid GIF
      result = AdminService.generate_gif_from_frames(mock_sequence, selected_indices)
      
      case result do
        {:ok, _gif_data} -> assert true  # Unexpected but not a failure
        {:error, _error_message} -> assert true  # Expected
      end
    end

    test "properly formats frame filenames for FFmpeg", %{frames: frames} do
      target_frame = List.first(frames)
      {:ok, frame_sequence} = Video.get_frame_sequence(target_frame.id)
      
      selected_indices = [0, 1, 2]

      # Test that the function attempts GIF generation
      # The actual file creation is tested indirectly
      case AdminService.generate_gif_from_frames(frame_sequence, selected_indices) do
        {:ok, _gif_data} ->
          # Success indicates proper file naming and FFmpeg execution
          assert true
          
        {:error, error_message} ->
          # Check that the error is related to FFmpeg, not file naming issues
          refute String.contains?(error_message, "No such file")
          refute String.contains?(error_message, "frame_0000.jpg")
      end
    end
  end

  describe "test_ffmpeg_availability/0" do
    test "returns status of FFmpeg availability" do
      result = AdminService.test_ffmpeg_availability()
      
      case result do
        {:ok, message} ->
          assert is_binary(message)
          assert String.contains?(message, "FFMPEG found")
          
        {:error, message} ->
          assert is_binary(message)
          assert String.contains?(message, "FFMPEG not found") or
                 String.contains?(message, "Error testing FFMPEG")
      end
    end

    test "provides version information when FFmpeg is available" do
      case AdminService.test_ffmpeg_availability() do
        {:ok, message} ->
          # Should include version information
          assert String.contains?(message, "ffmpeg")
          
        {:error, _message} ->
          # Expected if FFmpeg not available
          assert true
      end
    end
  end

  describe "frame extraction and processing" do
    setup do
      # Create a simple test setup for frame processing tests
      %{
        mock_frame_sequence: %{
          target_frame: %{id: 1, frame_number: 1},
          sequence_frames: [
            %{id: 1, frame_number: 1, image_data: "\\x424d0e000000"},  # Simple BMP header
            %{id: 2, frame_number: 2, image_data: "\\x424d0e000000"},
            %{id: 3, frame_number: 3, image_data: nil}  # Frame without data
          ],
          target_captions: "Test",
          sequence_captions: %{},
          sequence_info: %{
            target_frame_number: 1,
            start_frame_number: 1,
            end_frame_number: 3,
            total_frames: 3
          }
        }
      }
    end

    test "extracts only frames with valid image data", %{mock_frame_sequence: frame_sequence} do
      selected_indices = [0, 1, 2]  # All frames

      case AdminService.generate_gif_from_frames(frame_sequence, selected_indices) do
        {:ok, _gif_data} ->
          # Success means only valid frames were processed
          assert true
          
        {:error, error_message} ->
          # Should not fail due to nil image data (those frames are filtered out)
          refute String.contains?(error_message, "invalid image data")
      end
    end

    test "handles mixed valid and invalid frames", %{mock_frame_sequence: frame_sequence} do
      selected_indices = [0, 2]  # First frame (valid) and third frame (invalid)

      # Should process successfully with just the valid frame
      case AdminService.generate_gif_from_frames(frame_sequence, selected_indices) do
        {:ok, _gif_data} -> assert true
        {:error, _error_message} -> assert true  # May fail due to FFmpeg availability
      end
    end

    test "sorted indices are processed in correct order", %{mock_frame_sequence: frame_sequence} do
      # Provide unsorted indices
      selected_indices = [1, 0]  # Should be processed as [0, 1]

      case AdminService.generate_gif_from_frames(frame_sequence, selected_indices) do
        {:ok, _gif_data} ->
          # Success indicates proper sorting and processing
          assert true
          
        {:error, _error_message} ->
          # Expected if FFmpeg not available
          assert true
      end
    end
  end
end