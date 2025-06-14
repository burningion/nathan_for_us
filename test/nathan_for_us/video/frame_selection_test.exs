defmodule NathanForUs.Video.FrameSelectionTest do
  use NathanForUs.DataCase

  alias NathanForUs.Video
  alias NathanForUs.Video.Video, as: VideoSchema
  alias NathanForUs.Video.{VideoFrame, VideoCaption, FrameCaption}

  describe "get_frame_sequence/2" do
    setup do
      setup_video_with_frames()
    end

    test "returns frame sequence with default range", %{target_frame: target_frame} do
      {:ok, sequence} = Video.get_frame_sequence(target_frame.id)

      assert sequence.target_frame.id == target_frame.id
      assert sequence.sequence_info.target_frame_number == 10
      assert sequence.sequence_info.start_frame_number == 5
      assert sequence.sequence_info.end_frame_number == 15
      assert length(sequence.sequence_frames) == 11
    end

    test "handles custom sequence length", %{target_frame: target_frame} do
      {:ok, sequence} = Video.get_frame_sequence(target_frame.id, 3)

      assert sequence.sequence_info.start_frame_number == 7
      assert sequence.sequence_info.end_frame_number == 13
      assert length(sequence.sequence_frames) == 7
    end

    test "respects minimum frame number boundary", %{frames: frames} do
      first_frame = List.first(frames)
      {:ok, sequence} = Video.get_frame_sequence(first_frame.id)

      # Should not go below frame 1
      assert sequence.sequence_info.start_frame_number == 1
      assert sequence.sequence_info.end_frame_number == 6
    end

    test "includes target captions", %{target_frame: target_frame} do
      {:ok, sequence} = Video.get_frame_sequence(target_frame.id)

      assert sequence.target_captions == "Caption for frame 10"
    end

    test "includes sequence captions for all frames", %{target_frame: target_frame} do
      {:ok, sequence} = Video.get_frame_sequence(target_frame.id)

      # Should have captions for frames 5-15
      assert map_size(sequence.sequence_captions) == 11

      # Verify specific frame captions
      frame_with_caption = Enum.find(sequence.sequence_frames, &(&1.frame_number == 8))
      captions = Map.get(sequence.sequence_captions, frame_with_caption.id, [])
      assert "Caption for frame 8" in captions
    end

    test "returns error for non-existent frame" do
      assert {:error, :frame_not_found} = Video.get_frame_sequence(999_999)
    end
  end

  describe "get_frame_sequence_with_selected_indices/3" do
    setup do
      setup_video_with_frames()
    end

    test "uses default range when no selected indices provided", %{target_frame: target_frame} do
      {:ok, sequence} = Video.get_frame_sequence_with_selected_indices(target_frame.id, [])

      assert sequence.sequence_info.start_frame_number == 5
      assert sequence.sequence_info.end_frame_number == 15
      assert length(sequence.sequence_frames) == 11
    end

    test "expands range to cover selected indices beyond default", %{target_frame: target_frame} do
      # Default range for frame 10 would be 5-15 (indices 0-10)
      # Select index 15 which would map to frame 20 (5 + 15)
      selected_indices = [0, 5, 15]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, selected_indices)

      # Should expand to include frame 20
      assert sequence.sequence_info.start_frame_number == 5
      assert sequence.sequence_info.end_frame_number >= 20
      assert length(sequence.sequence_frames) >= 16
    end

    test "expands range backwards for low selected indices", %{frames: frames} do
      # Use a target frame that has room to expand backward
      later_frame = Enum.find(frames, &(&1.frame_number == 15))

      # Select indices that would go before the default start
      # Would map to frames 12, 15, 20 if default start is 15
      selected_indices = [-3, 0, 5]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(later_frame.id, selected_indices)

      # Should expand backward to include earlier frames
      # Expanded backward
      assert sequence.sequence_info.start_frame_number <= 10
      assert length(sequence.sequence_frames) > 11
    end

    test "handles extreme selected indices gracefully", %{target_frame: target_frame} do
      # Indices that would go way beyond available frames
      selected_indices = [0, 50, 100]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, selected_indices)

      # Should still return a valid sequence
      assert sequence.sequence_info.start_frame_number >= 1
      # Our test data only has 20 frames
      assert sequence.sequence_info.end_frame_number <= 20
      assert length(sequence.sequence_frames) > 0
    end

    test "works with single selected index", %{target_frame: target_frame} do
      # Single index outside center
      selected_indices = [8]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, selected_indices)

      # Should include the frame at that index
      # 5 + 8
      assert sequence.sequence_info.start_frame_number <= 13
      assert sequence.sequence_info.end_frame_number >= 13
    end

    test "maintains same structure as original function", %{target_frame: target_frame} do
      {:ok, sequence} = Video.get_frame_sequence_with_selected_indices(target_frame.id, [])

      # Should have all the same fields
      assert Map.has_key?(sequence, :target_frame)
      assert Map.has_key?(sequence, :sequence_frames)
      assert Map.has_key?(sequence, :target_captions)
      assert Map.has_key?(sequence, :sequence_captions)
      assert Map.has_key?(sequence, :sequence_info)

      # Sequence info should have required fields
      assert Map.has_key?(sequence.sequence_info, :target_frame_number)
      assert Map.has_key?(sequence.sequence_info, :start_frame_number)
      assert Map.has_key?(sequence.sequence_info, :end_frame_number)
      assert Map.has_key?(sequence.sequence_info, :total_frames)
    end

    test "custom base sequence length affects calculation", %{target_frame: target_frame} do
      selected_indices = [0, 2]

      {:ok, sequence_default} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, selected_indices, 5)

      {:ok, sequence_small} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, selected_indices, 2)

      # Smaller base length should result in different range calculation
      assert sequence_default.sequence_info.start_frame_number !=
               sequence_small.sequence_info.start_frame_number ||
               sequence_default.sequence_info.end_frame_number !=
                 sequence_small.sequence_info.end_frame_number
    end

    test "returns error for non-existent frame" do
      assert {:error, :frame_not_found} =
               Video.get_frame_sequence_with_selected_indices(999_999, [0, 1, 2])
    end
  end

  describe "calculate_range_for_selected_indices/3 (private function behavior)" do
    setup do
      setup_video_with_frames()
    end

    test "range calculation with empty indices uses default", %{target_frame: target_frame} do
      # Test the behavior through the public function
      {:ok, sequence} = Video.get_frame_sequence_with_selected_indices(target_frame.id, [])

      # Should match default get_frame_sequence behavior
      {:ok, default_sequence} = Video.get_frame_sequence(target_frame.id)

      assert sequence.sequence_info.start_frame_number ==
               default_sequence.sequence_info.start_frame_number

      assert sequence.sequence_info.end_frame_number ==
               default_sequence.sequence_info.end_frame_number
    end

    test "range calculation expands for indices beyond default range", %{
      target_frame: target_frame
    } do
      # Target frame 10, default range 5-15, indices that go beyond
      # Would map to frames 5, 25, 30
      large_indices = [0, 20, 25]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, large_indices)

      # Should expand to cover the largest index
      # At least frame 20
      assert sequence.sequence_info.end_frame_number >= 20
    end

    test "range calculation handles negative implications", %{frames: frames} do
      # Use a frame where negative indices would make sense
      # Frame 15
      later_frame = Enum.at(frames, 14)
      # Conceptually before default start
      negative_effect_indices = [-2, 0, 5]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(later_frame.id, negative_effect_indices)

      # Should handle gracefully without going below frame 1
      assert sequence.sequence_info.start_frame_number >= 1
    end
  end

  describe "frame sequence with captions integration" do
    setup do
      setup_video_with_frames()
    end

    test "selected indices expansion includes captions for new frames", %{
      target_frame: target_frame
    } do
      # Select indices that will expand the range
      # Should map to frames 5 and 17
      selected_indices = [0, 12]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, selected_indices)

      # Should have captions for the expanded range
      frame_17 = Enum.find(sequence.sequence_frames, &(&1.frame_number == 17))

      if frame_17 do
        captions = Map.get(sequence.sequence_captions, frame_17.id, [])
        assert "Caption for frame 17" in captions
      end
    end

    test "target captions remain consistent regardless of selection", %{
      target_frame: target_frame
    } do
      {:ok, sequence_default} = Video.get_frame_sequence(target_frame.id)

      {:ok, sequence_expanded} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, [0, 15])

      assert sequence_default.target_captions == sequence_expanded.target_captions
    end
  end

  describe "edge cases and error handling" do
    setup do
      setup_video_with_frames()
    end

    test "very large selected indices don't crash", %{target_frame: target_frame} do
      huge_indices = [0, 1000, 999_999]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, huge_indices)

      # Should complete without error
      assert is_list(sequence.sequence_frames)
      assert length(sequence.sequence_frames) > 0
    end

    test "negative selected indices are handled", %{target_frame: target_frame} do
      negative_indices = [-5, 0, 5]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, negative_indices)

      # Should not crash and maintain valid frame numbers
      assert sequence.sequence_info.start_frame_number >= 1
      assert length(sequence.sequence_frames) > 0
    end

    test "duplicate selected indices are handled", %{target_frame: target_frame} do
      duplicate_indices = [0, 0, 5, 5, 10, 10]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, duplicate_indices)

      # Should work without issues
      assert length(sequence.sequence_frames) > 0
    end

    test "unsorted selected indices work correctly", %{target_frame: target_frame} do
      unsorted_indices = [10, 0, 5, 15, 2]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, unsorted_indices)

      # Should handle unsorted input correctly
      assert sequence.sequence_info.start_frame_number <= sequence.sequence_info.end_frame_number
      assert length(sequence.sequence_frames) > 0
    end
  end

  describe "performance and data consistency" do
    setup do
      setup_video_with_frames()
    end

    test "expanded sequence maintains frame order", %{target_frame: target_frame} do
      # Unsorted to test ordering
      selected_indices = [0, 8, 15, 3]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, selected_indices)

      # Frames should be in ascending order by frame_number
      frame_numbers = Enum.map(sequence.sequence_frames, & &1.frame_number)
      assert frame_numbers == Enum.sort(frame_numbers)
    end

    test "sequence_info totals are accurate", %{target_frame: target_frame} do
      selected_indices = [0, 5, 12]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, selected_indices)

      # Total frames should match actual loaded frames
      assert sequence.sequence_info.total_frames == length(sequence.sequence_frames)

      # Range should be consistent
      expected_range =
        sequence.sequence_info.end_frame_number - sequence.sequence_info.start_frame_number + 1

      # Note: expected_range might be larger than total_frames if some frames don't exist in DB
      assert sequence.sequence_info.total_frames <= expected_range
    end

    test "no duplicate frames in expanded sequence", %{target_frame: target_frame} do
      # Many overlapping indices
      selected_indices = [0, 1, 2, 3, 4, 5]

      {:ok, sequence} =
        Video.get_frame_sequence_with_selected_indices(target_frame.id, selected_indices)

      # Should not have duplicate frames
      frame_ids = Enum.map(sequence.sequence_frames, & &1.id)
      assert length(frame_ids) == length(Enum.uniq(frame_ids))
    end
  end

  # Helper function to set up test data
  defp setup_video_with_frames do
    # Create test video
    {:ok, video} =
      %VideoSchema{}
      |> VideoSchema.changeset(%{
        title: "Test Video",
        file_path: "/test/video.mp4",
        duration_ms: 20000,
        fps: 30.0,
        frame_count: 20,
        status: "completed"
      })
      |> Repo.insert()

    # Create test frames (1-20)
    frames =
      for i <- 1..20 do
        %{
          frame_number: i,
          timestamp_ms: i * 1000,
          file_path: "frame_#{i}.jpg",
          file_size: 1000,
          width: 1920,
          height: 1080,
          video_id: video.id,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end

    {_count, frame_records} = Repo.insert_all(VideoFrame, frames, returning: true)

    # Create test captions
    captions =
      for i <- 1..20 do
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
    frame_caption_links =
      for {frame, caption} <- Enum.zip(frame_records, caption_records) do
        %{
          frame_id: frame.id,
          caption_id: caption.id,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end

    Repo.insert_all(FrameCaption, frame_caption_links)

    # Return test data
    target_frame = Enum.find(frame_records, &(&1.frame_number == 10))

    %{
      video: video,
      frames: frame_records,
      captions: caption_records,
      target_frame: target_frame
    }
  end
end
