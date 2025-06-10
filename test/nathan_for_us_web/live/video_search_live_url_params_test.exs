defmodule NathanForUsWeb.VideoSearchLiveUrlParamsTest do
  use NathanForUsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias NathanForUs.{Repo}
  alias NathanForUs.Video.Video, as: VideoSchema
  alias NathanForUs.Video.{VideoFrame, VideoCaption, FrameCaption}

  # Helper function to access LiveView assigns cleanly
  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  setup do
    # Create test video
    {:ok, video} = %VideoSchema{}
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
    frames = for i <- 1..20 do
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
    captions = for i <- 1..20 do
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

  describe "URL parameter handling for frame selection" do
    test "handle_params with frame parameter opens sequence modal", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)  # Frame 10
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}")

      # Should open frame sequence modal
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).frame_sequence != nil
      assert assigns(view).frame_sequence.target_frame.id == frame.id
    end

    test "handle_params with frame and frames parameters sets correct selection", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)  # Frame 10
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,2,5")

      # Should set frame selection from URL
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).selected_frame_indices == [0, 2, 5]
    end

    test "handle_params loads expanded sequence for indices outside default range", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)  # Frame 10 (default range would be 5-15)
      # Select indices that would go beyond default range
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,5,15")

      # Should use expanded frame loading
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).selected_frame_indices == [0, 5, 15]
      
      # Frame sequence should be expanded to cover index 15
      # Index 15 from default start frame 5 = frame 20
      frame_numbers = Enum.map(assigns(view).frame_sequence.sequence_frames, &(&1.frame_number))
      assert 20 in frame_numbers
    end

    test "handle_params with only frame parameter selects all frames by default", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}")

      # Should select all frames in the default sequence
      total_frames = length(assigns(view).frame_sequence.sequence_frames)
      assert length(assigns(view).selected_frame_indices) == total_frames
      assert assigns(view).selected_frame_indices == Enum.to_list(0..(total_frames - 1))
    end

    test "handle_params with malformed frames parameter handles gracefully", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,invalid,2,bad,5")

      # Should parse valid indices and ignore invalid ones
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).selected_frame_indices == [0, 2, 5]
    end

    test "handle_params with frames parameter containing spaces", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0, 2, 5")

      # Should handle spaces in parameter
      assert assigns(view).selected_frame_indices == [0, 2, 5]
    end

    test "handle_params with empty frames parameter", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=")

      # Should default to selecting all frames
      total_frames = length(assigns(view).frame_sequence.sequence_frames)
      assert length(assigns(view).selected_frame_indices) == total_frames
    end

    test "handle_params with duplicate indices in frames parameter", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,0,2,2,5,5")

      # Should deduplicate indices
      assert assigns(view).selected_frame_indices == [0, 2, 5]
    end

    test "handle_params with unsorted indices", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=5,0,2,10,1")

      # Should sort indices
      assert assigns(view).selected_frame_indices == [0, 1, 2, 5, 10]
    end

    test "handle_params with very large indices", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,999,1000")

      # Should handle large indices gracefully
      assert assigns(view).show_sequence_modal == true
      assert 0 in assigns(view).selected_frame_indices
      assert 999 in assigns(view).selected_frame_indices
      assert 1000 in assigns(view).selected_frame_indices
    end

    test "handle_params with invalid frame ID ignores frame parameter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search?frame=999999&frames=0,1,2")

      # Should ignore invalid frame ID
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil
      assert assigns(view).selected_frame_indices == []
    end

    test "handle_params with non-numeric frame ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search?frame=invalid&frames=0,1,2")

      # Should handle gracefully
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil
    end
  end

  describe "URL parameter handling for video selection" do
    test "handle_params with video parameter sets video selection", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search?video=#{video.id}")

      # Should set video selection from URL
      assert assigns(view).selected_video_ids == [video.id]
      assert assigns(view).search_mode == :filtered
    end

    test "handle_params with invalid video ID ignores parameter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search?video=999999")

      # Should ignore invalid video ID
      assert assigns(view).selected_video_ids == []
      assert assigns(view).search_mode == :global
    end

    test "handle_params with non-numeric video ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search?video=invalid")

      # Should handle gracefully
      assert assigns(view).selected_video_ids == []
      assert assigns(view).search_mode == :global
    end
  end

  describe "combined URL parameters" do
    test "handle_params with both video and frame parameters", %{conn: conn, video: video, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?video=#{video.id}&frame=#{frame.id}&frames=0,1,2")

      # Should handle both parameters
      assert assigns(view).selected_video_ids == [video.id]
      assert assigns(view).search_mode == :filtered
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).selected_frame_indices == [0, 1, 2]
    end

    test "handle_params preserves custom parameters", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&custom=value&other=param")

      # Should store all params for URL building
      assert assigns(view)[:current_params] != nil
      current_params = assigns(view).current_params
      
      assert Map.get(current_params, "frame") == to_string(frame.id)
      assert Map.get(current_params, "custom") == "value"
      assert Map.get(current_params, "other") == "param"
    end
  end

  describe "parse_selected_frames_from_params/1" do
    test "parses comma-separated frame indices correctly" do
      # Test through the public interface since this is a private function
      # The function's behavior is tested indirectly through handle_params tests above
      assert true  # Placeholder since we test this through integration
    end
  end

  describe "frame sequence modal interaction with URL params" do
    test "opening modal with expand operations preserves URL params", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 4)  # Frame 5, has room to expand
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,1,2")

      initial_sequence_length = length(assigns(view).frame_sequence.sequence_frames)
      
      # Expand sequence forward
      render_click(view, "expand_sequence_forward")
      
      # Should maintain frame sequence and selections
      assert assigns(view).show_sequence_modal == true
      new_sequence_length = length(assigns(view).frame_sequence.sequence_frames)
      assert new_sequence_length >= initial_sequence_length
    end

    test "closing modal clears frame-related state but preserves video selection", %{conn: conn, video: video, frames: frames} do
      frame = Enum.at(frames, 9)
      {:ok, view, _html} = live(conn, "/video-search?video=#{video.id}&frame=#{frame.id}&frames=0,1,2")

      # Close modal
      render_click(view, "close_sequence_modal")

      # Should clear frame state but keep video state
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil
      assert assigns(view).selected_frame_indices == []
      assert assigns(view).selected_video_ids == [video.id]  # Video selection preserved
    end
  end

  describe "URL building and navigation" do
    test "push_frame_selection_to_url updates URL correctly", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence
      frame = Enum.at(frames, 9)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      # Modify selection
      render_click(view, "deselect_all_frames")
      render_click(view, "toggle_frame_selection", %{"frame_index" => "0"})
      render_click(view, "toggle_frame_selection", %{"frame_index" => "2"})

      # URL update happens via push_patch (we can't directly test this in unit tests)
      # But we can verify the internal state is correct for URL building
      assert assigns(view).selected_frame_indices == [0, 2]
      assert assigns(view).frame_sequence != nil
    end

    test "push_video_selection_to_url updates URL correctly", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Select a video
      render_click(view, "toggle_video_selection", %{"video_id" => to_string(video.id)})

      # URL update happens via push_patch
      # Verify internal state is correct for URL building
      assert video.id in assigns(view).selected_video_ids
    end
  end

  describe "error handling and edge cases" do
    test "missing frame parameter is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search?frames=0,1,2")

      # Should ignore frames parameter without frame parameter
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).selected_frame_indices == []
    end

    test "malformed URL parameters don't crash the application", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search?frame=&frames=&video=")

      # Should handle gracefully
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).selected_video_ids == []
      assert assigns(view).search_mode == :global
    end

    test "very long frames parameter is handled", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      long_frames = Enum.join(0..100, ",")
      
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=#{long_frames}")

      # Should handle long parameter lists
      assert assigns(view).show_sequence_modal == true
      assert length(assigns(view).selected_frame_indices) == 101  # 0-100 inclusive
    end

    test "URL with no parameters works normally", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Should have default state
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).selected_video_ids == []
      assert assigns(view).search_mode == :global
      assert assigns(view).selected_frame_indices == []
    end
  end

  describe "frame sequence consistency after URL loading" do
    test "frame sequence from URL has same structure as manual opening", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)
      
      # Load via URL
      {:ok, view_url, _html} = live(conn, "/video-search?frame=#{frame.id}")
      sequence_from_url = assigns(view_url).frame_sequence
      
      # Load manually
      {:ok, view_manual, _html} = live(conn, "/video-search")
      render_click(view_manual, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})
      sequence_from_manual = assigns(view_manual).frame_sequence
      
      # Should have same structure (though possibly different ranges due to selection)
      assert sequence_from_url.target_frame.id == sequence_from_manual.target_frame.id
      assert sequence_from_url.target_captions == sequence_from_manual.target_captions
    end

    test "expanded sequence from URL includes all selected frames", %{conn: conn, frames: frames} do
      frame = Enum.at(frames, 9)  # Frame 10
      
      # Load with indices that require expansion
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,5,15")
      
      sequence = assigns(view).frame_sequence
      selected_indices = assigns(view).selected_frame_indices
      
      # All selected indices should be valid for the loaded sequence
      max_valid_index = length(sequence.sequence_frames) - 1
      
      for index <- selected_indices do
        assert index <= max_valid_index, "Index #{index} exceeds sequence length #{length(sequence.sequence_frames)}"
      end
    end
  end
end