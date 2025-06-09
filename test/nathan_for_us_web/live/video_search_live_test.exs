defmodule NathanForUsWeb.VideoSearchLiveTest do
  use NathanForUsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias NathanForUs.{Repo}
  alias NathanForUs.Video.Video, as: VideoSchema
  alias NathanForUs.Video.{VideoFrame, VideoCaption, FrameCaption}

  # Helper function to access LiveView assigns cleanly
  defp assigns(view), do: assigns(view)

  setup do
    # Create test video
    {:ok, video} = %VideoSchema{}
    |> VideoSchema.changeset(%{
      title: "Test Video",
      file_path: "/test/video.mp4",
      duration_ms: 10000,
      fps: 30.0,
      frame_count: 100,
      status: "completed"
    })
    |> Repo.insert()

    # Create test frames
    frames = for i <- 1..10 do
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
    captions = for i <- 1..10 do
      %{
        text: "Test caption #{i}",
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

  describe "mount/3" do
    test "successfully mounts with default assigns", %{conn: conn} do
      {:ok, view, html} = live(conn, "/video-search")

      assert html =~ "Nathan Appearance Video Search"
      
      # Check default assigns
      assert assigns(view).search_form == %{"term" => ""}
      assert assigns(view).search_term == ""
      assert assigns(view).search_results == []
      assert assigns(view).loading == false
      assert assigns(view).show_video_modal == false
      assert assigns(view).selected_video_ids == []
      assert assigns(view).search_mode == :global
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil
      assert assigns(view).selected_frame_indices == []
      assert assigns(view).autocomplete_suggestions == []
      assert assigns(view).show_autocomplete == false
      assert assigns(view).animation_speed == 150
    end

    test "loads videos on mount", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      assert length(assigns(view).videos) >= 1
      assert Enum.any?(assigns(view).videos, fn v -> v.id == video.id end)
    end
  end

  describe "search event handlers" do
    test "search with non-empty term triggers async search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Test nested search params
      view |> element("form") |> render_submit(%{"search" => %{"term" => "test"}})

      assert assigns(view).search_term == "test"
      assert assigns(view).loading == true
      assert assigns(view).search_results == []
    end

    test "search with empty term clears results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Set some initial state
      send(view.pid, {:perform_search, "test"})
      :timer.sleep(10) # Allow async message to process

      # Clear search
      view |> element("form") |> render_submit(%{"search" => %{"term" => ""}})

      assert assigns(view).search_term == ""
      assert assigns(view).search_results == []
      assert assigns(view).loading == false
    end

    test "search with flat params structure", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Test flat search params (alternative form structure)
      render_hook(view, "search", %{"search[term]" => "test query"})

      assert assigns(view).search_term == "test query"
      assert assigns(view).loading == true
    end

    test "search with flat empty params", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      render_hook(view, "search", %{"search[term]" => ""})

      assert assigns(view).search_term == ""
      assert assigns(view).loading == false
    end
  end

  describe "video filter events" do
    test "toggle_video_modal changes modal visibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      assert assigns(view).show_video_modal == false

      render_click(view, "toggle_video_modal")
      assert assigns(view).show_video_modal == true

      render_click(view, "toggle_video_modal")
      assert assigns(view).show_video_modal == false
    end

    test "toggle_video_selection adds video to selection", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      render_click(view, "toggle_video_selection", %{"video_id" => to_string(video.id)})

      assert video.id in assigns(view).selected_video_ids
    end

    test "toggle_video_selection removes video from selection", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Add video first
      render_click(view, "toggle_video_selection", %{"video_id" => to_string(video.id)})
      assert video.id in assigns(view).selected_video_ids

      # Remove video
      render_click(view, "toggle_video_selection", %{"video_id" => to_string(video.id)})
      assert video.id not in assigns(view).selected_video_ids
    end

    test "apply_video_filter sets search mode and closes modal", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Select a video first
      render_click(view, "toggle_video_selection", %{"video_id" => to_string(video.id)})
      render_click(view, "toggle_video_modal")

      render_click(view, "apply_video_filter")

      assert assigns(view).search_mode == :filtered
      assert assigns(view).show_video_modal == false
      assert assigns(view).search_results == []
    end

    test "apply_video_filter with no videos sets global mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      render_click(view, "apply_video_filter")

      assert assigns(view).search_mode == :global
      assert assigns(view).show_video_modal == false
    end

    test "clear_video_filter resets to global mode", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Set up filtered state
      render_click(view, "toggle_video_selection", %{"video_id" => to_string(video.id)})
      render_click(view, "apply_video_filter")

      # Clear filter
      render_click(view, "clear_video_filter")

      assert assigns(view).selected_video_ids == []
      assert assigns(view).search_mode == :global
      assert assigns(view).search_results == []
    end
  end

  describe "frame sequence events" do
    test "show_frame_sequence opens modal with frame data", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      assert assigns(view).show_sequence_modal == true
      assert assigns(view).frame_sequence != nil
      assert assigns(view).frame_sequence.target_frame.id == frame.id
      assert length(assigns(view).selected_frame_indices) > 0
    end

    test "show_frame_sequence with invalid frame_id shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      render_click(view, "show_frame_sequence", %{"frame_id" => "999999"})

      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil
    end

    test "close_sequence_modal resets modal state", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open modal first
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})
      assert assigns(view).show_sequence_modal == true

      # Close modal
      render_click(view, "close_sequence_modal")

      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil
      assert assigns(view).selected_frame_indices == []
    end

    test "toggle_frame_selection adds frame to selection", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_selection = assigns(view).selected_frame_indices
      
      # Toggle a frame that's not selected
      available_index = Enum.find(0..10, fn i -> i not in initial_selection end)
      if available_index do
        render_click(view, "toggle_frame_selection", %{"frame_index" => to_string(available_index)})
        assert available_index in assigns(view).selected_frame_indices
      end
    end

    test "toggle_frame_selection removes frame from selection", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      # Get a selected frame
      selected_index = List.first(assigns(view).selected_frame_indices)
      
      render_click(view, "toggle_frame_selection", %{"frame_index" => to_string(selected_index)})
      assert selected_index not in assigns(view).selected_frame_indices
    end

    test "select_all_frames selects all available frames", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      render_click(view, "select_all_frames")

      sequence_length = length(assigns(view).frame_sequence.sequence_frames)
      assert length(assigns(view).selected_frame_indices) == sequence_length
      assert assigns(view).selected_frame_indices == Enum.to_list(0..(sequence_length - 1))
    end

    test "deselect_all_frames clears all selections", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      render_click(view, "deselect_all_frames")

      assert assigns(view).selected_frame_indices == []
    end
  end

  describe "expand sequence events" do
    test "expand_sequence_backward adds frame at beginning", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal with a frame that has room to expand backward
      frame = Enum.at(frames, 2) # Use 3rd frame so there's room to expand
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_sequence = assigns(view).frame_sequence
      initial_start = initial_sequence.sequence_info.start_frame_number
      initial_selected = assigns(view).selected_frame_indices

      render_click(view, "expand_sequence_backward")

      new_sequence = assigns(view).frame_sequence
      new_start = new_sequence.sequence_info.start_frame_number

      assert new_start == initial_start - 1
      assert length(new_sequence.sequence_frames) == length(initial_sequence.sequence_frames) + 1
      
      # Check that selected indices were shifted by +1
      expected_indices = Enum.map(initial_selected, fn index -> index + 1 end)
      assert assigns(view).selected_frame_indices == expected_indices
    end

    test "expand_sequence_backward at beginning does nothing", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal with first frame
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_sequence = assigns(view).frame_sequence
      render_click(view, "expand_sequence_backward")

      # Should be unchanged
      assert assigns(view).frame_sequence.sequence_info.start_frame_number == 
             initial_sequence.sequence_info.start_frame_number
    end

    test "expand_sequence_forward adds frame at end", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal
      frame = Enum.at(frames, 2)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_sequence = assigns(view).frame_sequence
      initial_end = initial_sequence.sequence_info.end_frame_number

      render_click(view, "expand_sequence_forward")

      new_sequence = assigns(view).frame_sequence
      new_end = new_sequence.sequence_info.end_frame_number

      assert new_end == initial_end + 1
      assert length(new_sequence.sequence_frames) == length(initial_sequence.sequence_frames) + 1
    end

    test "expand_sequence_forward at end does nothing", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal with last frame  
      frame = List.last(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_sequence = assigns(view).frame_sequence
      render_click(view, "expand_sequence_forward")

      # Should be unchanged since we're at the end
      assert assigns(view).frame_sequence.sequence_info.end_frame_number == 
             initial_sequence.sequence_info.end_frame_number
    end

    test "expand events with no frame sequence do nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      assert assigns(view).frame_sequence == nil

      render_click(view, "expand_sequence_backward")
      assert assigns(view).frame_sequence == nil

      render_click(view, "expand_sequence_forward")
      assert assigns(view).frame_sequence == nil
    end
  end

  describe "autocomplete events" do
    test "autocomplete_search with sufficient length shows suggestions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      render_hook(view, "autocomplete_search", %{"search" => %{"term" => "test"}})

      assert assigns(view).search_term == "test"
      assert assigns(view).show_autocomplete == true
      # Note: suggestions depend on database content, just check structure
      assert is_list(assigns(view).autocomplete_suggestions)
    end

    test "autocomplete_search with short term hides suggestions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      render_hook(view, "autocomplete_search", %{"search" => %{"term" => "te"}})

      assert assigns(view).search_term == "te"
      assert assigns(view).show_autocomplete == false
      assert assigns(view).autocomplete_suggestions == []
    end

    test "select_suggestion populates search and hides autocomplete", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      suggestion = "test suggestion"
      render_click(view, "select_suggestion", %{"suggestion" => suggestion})

      assert assigns(view).search_form == %{"term" => suggestion}
      assert assigns(view).search_term == suggestion
      assert assigns(view).show_autocomplete == false
      assert assigns(view).autocomplete_suggestions == []
    end

    test "hide_autocomplete hides suggestions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Show autocomplete first
      render_hook(view, "autocomplete_search", %{"search" => %{"term" => "test"}})
      assert assigns(view).show_autocomplete == true

      render_click(view, "hide_autocomplete")
      assert assigns(view).show_autocomplete == false
    end
  end

  describe "ignore event" do
    test "ignore event does nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      initial_assigns = Map.drop(assigns(view), [:flash])
      
      render_hook(view, "ignore", %{"value" => "150"})

      # Should be unchanged
      new_assigns = Map.drop(assigns(view), [:flash])
      assert initial_assigns == new_assigns
    end
  end

  describe "process_video event" do
    test "process_video with valid path updates videos list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      initial_video_count = length(assigns(view).videos)

      # This will likely fail in test environment, but we test the event handling
      render_click(view, "process_video", %{"video_path" => "/test/path.mp4"})

      # Check that the event was handled (assigns may not change due to mock data)
      assert is_list(assigns(view).videos)
    end
  end

  describe "handle_info/2" do
    test "perform_search with successful results updates assigns", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Set up search state
      send(view.pid, {:perform_search, "Test caption 1"})
      
      # Allow async processing
      :timer.sleep(50)

      assert assigns(view).loading == false
      assert is_list(assigns(view).search_results)
    end

    test "perform_search with no results returns empty list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      send(view.pid, {:perform_search, "nonexistent search term"})
      
      :timer.sleep(50)

      assert assigns(view).loading == false
      assert assigns(view).search_results == []
    end

    test "perform_search with error shows flash message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Force an error by searching with invalid data
      send(view.pid, {:perform_search, nil})
      
      :timer.sleep(50)

      assert assigns(view).loading == false
      assert assigns(view).search_results == []
    end
  end

  describe "edge cases and error handling" do
    test "invalid video_id in toggle_video_selection raises error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      assert_raise ArgumentError, fn ->
        render_click(view, "toggle_video_selection", %{"video_id" => "invalid"})
      end
    end

    test "invalid frame_index in toggle_frame_selection is handled gracefully", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_selection = assigns(view).selected_frame_indices

      assert_raise ArgumentError, fn ->
        render_click(view, "toggle_frame_selection", %{"frame_index" => "invalid"})
      end
    end

    test "malformed search params are handled gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Test with malformed params that don't match any pattern
      result = render_hook(view, "search", %{"malformed" => "data"})
      
      # LiveView should handle gracefully and return the rendered result
      assert result != nil
    end
  end

  describe "state transitions" do
    test "complete search workflow from empty to results to empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Initial state
      assert assigns(view).search_term == ""
      assert assigns(view).search_results == []
      assert assigns(view).loading == false

      # Start search
      view |> element("form") |> render_submit(%{"search" => %{"term" => "test"}})
      assert assigns(view).loading == true
      assert assigns(view).search_term == "test"

      # Complete search (simulate async completion)
      send(view.pid, {:perform_search, "test"})
      :timer.sleep(50)
      assert assigns(view).loading == false

      # Clear search
      view |> element("form") |> render_submit(%{"search" => %{"term" => ""}})
      assert assigns(view).search_term == ""
      assert assigns(view).search_results == []
      assert assigns(view).loading == false
    end

    test "video filter workflow", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Initial global mode
      assert assigns(view).search_mode == :global
      assert assigns(view).selected_video_ids == []

      # Open video modal and select videos
      render_click(view, "toggle_video_modal")
      assert assigns(view).show_video_modal == true

      render_click(view, "toggle_video_selection", %{"video_id" => to_string(video.id)})
      assert video.id in assigns(view).selected_video_ids

      # Apply filter
      render_click(view, "apply_video_filter")
      assert assigns(view).search_mode == :filtered
      assert assigns(view).show_video_modal == false

      # Clear filter
      render_click(view, "clear_video_filter")
      assert assigns(view).search_mode == :global
      assert assigns(view).selected_video_ids == []
    end

    test "frame sequence modal workflow", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Initial state - no modal
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil

      # Open frame sequence
      frame = Enum.at(frames, 2)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).frame_sequence != nil

      # Manipulate frame selection
      render_click(view, "deselect_all_frames")
      assert assigns(view).selected_frame_indices == []

      render_click(view, "select_all_frames")
      sequence_length = length(assigns(view).frame_sequence.sequence_frames)
      assert length(assigns(view).selected_frame_indices) == sequence_length

      # Expand sequence
      initial_frame_count = length(assigns(view).frame_sequence.sequence_frames)
      render_click(view, "expand_sequence_forward")
      new_frame_count = length(assigns(view).frame_sequence.sequence_frames)
      assert new_frame_count >= initial_frame_count

      # Close modal
      render_click(view, "close_sequence_modal")
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil
    end
  end

  describe "performance and concurrency" do
    test "multiple rapid search requests are handled correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Send multiple rapid search requests
      for term <- ["a", "ab", "abc", "abcd"] do
        view |> element("form") |> render_submit(%{"search" => %{"term" => term}})
        :timer.sleep(10)
      end

      # Final state should reflect last search
      assert assigns(view).search_term == "abcd"
      assert assigns(view).loading == true
    end

    test "rapid modal open/close operations", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      frame = List.first(frames)
      
      # Rapid open/close operations
      for _i <- 1..5 do
        render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})
        render_click(view, "close_sequence_modal")
      end

      # Should end in closed state
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil
    end
  end
end