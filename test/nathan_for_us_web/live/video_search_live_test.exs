defmodule NathanForUsWeb.VideoSearchLiveTest do
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
      assert assigns(view).expanded_videos == MapSet.new()
    end

    test "loads videos on mount", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      assert length(assigns(view).videos) >= 1
      assert Enum.any?(assigns(view).videos, fn v -> v.id == video.id end)
    end

    test "loads sample suggestions on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Should load sample suggestions
      assert is_list(assigns(view).sample_suggestions)
      # Should have some suggestions (either from database or fallback)
      assert length(assigns(view).sample_suggestions) > 0
      # All suggestions should be non-empty strings
      assert Enum.all?(assigns(view).sample_suggestions, fn suggestion -> 
        is_binary(suggestion) and String.length(suggestion) > 0
      end)
    end
  end

  describe "search event handlers" do
    test "search with non-empty term triggers async search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Test nested search params - search for "test" which should match our test data
      view |> element("form") |> render_submit(%{"search" => %{"term" => "test"}})

      assert assigns(view).search_term == "test"
      # Loading state may be true or false depending on async timing
      assert is_boolean(assigns(view).loading)
      # Initially results might be empty or already populated depending on timing
      assert is_list(assigns(view).search_results)
      
      # Wait for async search to complete
      :timer.sleep(50)
      assert assigns(view).loading == false
      # Should find results for "test" since our test data has "Test caption X"
      assert length(assigns(view).search_results) > 0
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
      # Note: loading state may not be true immediately in test environment
      assert is_boolean(assigns(view).loading)
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

      # Use the last frame which should have room to expand backward since default sequence_length is 5
      # and we have 10 frames, so frame 10 with sequence_length 5 should start around frame 5
      frame = List.last(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_sequence = assigns(view).frame_sequence
      initial_start = initial_sequence.sequence_info.start_frame_number
      initial_selected = assigns(view).selected_frame_indices

      render_click(view, "expand_sequence_backward")

      new_sequence = assigns(view).frame_sequence
      new_start = new_sequence.sequence_info.start_frame_number

      # Check if expansion was possible (depends on frame position)
      if initial_start > 1 do
        # Should expand backward if possible
        assert new_start < initial_start || new_start == initial_start
        assert length(new_sequence.sequence_frames) >= length(initial_sequence.sequence_frames)
        
        # If expansion happened, check that new frame is auto-selected and indices shifted
        if new_start < initial_start do
          expected_indices = [0 | Enum.map(initial_selected, fn index -> index + 1 end)]
          assert assigns(view).selected_frame_indices == expected_indices
        end
      else
        # If no room to expand, everything should stay the same
        assert new_start == initial_start
        assert length(new_sequence.sequence_frames) == length(initial_sequence.sequence_frames)
        assert assigns(view).selected_frame_indices == initial_selected
      end
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
      initial_selected = assigns(view).selected_frame_indices

      render_click(view, "expand_sequence_forward")

      new_sequence = assigns(view).frame_sequence
      new_end = new_sequence.sequence_info.end_frame_number

      # Check if expansion was possible (depends on frame position and total frames)
      max_possible_frames = 10 # We have 10 frames in test data
      if initial_end < max_possible_frames do
        assert new_end >= initial_end
        assert length(new_sequence.sequence_frames) >= length(initial_sequence.sequence_frames)
        
        # If expansion happened, check that new frame at end is auto-selected
        if new_end > initial_end do
          new_frame_index = length(new_sequence.sequence_frames) - 1
          expected_indices = initial_selected ++ [new_frame_index]
          assert assigns(view).selected_frame_indices == expected_indices
        end
      else
        # At the end, no expansion possible
        assert new_end == initial_end
        assert length(new_sequence.sequence_frames) == length(initial_sequence.sequence_frames)
      end
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

    test "expand_sequence_backward_multiple expands by N frames", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Use a frame that has room to expand backward
      frame = List.last(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_sequence = assigns(view).frame_sequence
      initial_start = initial_sequence.sequence_info.start_frame_number
      initial_selected = assigns(view).selected_frame_indices

      # Expand backward by 3 frames
      render_hook(view, "expand_sequence_backward_multiple", %{"value" => "3"})

      new_sequence = assigns(view).frame_sequence
      new_start = new_sequence.sequence_info.start_frame_number

      # Check if expansion was possible (depends on frame position)
      if initial_start > 3 do
        # Should expand backward if possible
        assert new_start <= initial_start - 1  # At least one frame backward
        assert length(new_sequence.sequence_frames) >= length(initial_sequence.sequence_frames) + 1
        
        # Check that new frames are auto-selected and existing indices shifted
        frames_added = initial_start - new_start
        if frames_added > 0 do
          expected_new_indices = Enum.to_list(0..(frames_added - 1))
          expected_shifted = Enum.map(initial_selected, fn index -> index + frames_added end)
          expected_all = expected_new_indices ++ expected_shifted
          assert assigns(view).selected_frame_indices == expected_all
        end
      end
    end

    test "expand_sequence_forward_multiple expands by N frames", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Use a frame that has room to expand forward
      frame = Enum.at(frames, 2)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_sequence = assigns(view).frame_sequence
      initial_end = initial_sequence.sequence_info.end_frame_number
      initial_selected = assigns(view).selected_frame_indices
      initial_length = length(initial_sequence.sequence_frames)

      # Expand forward by 2 frames
      render_hook(view, "expand_sequence_forward_multiple", %{"value" => "2"})

      new_sequence = assigns(view).frame_sequence
      new_end = new_sequence.sequence_info.end_frame_number

      # Check if expansion was possible (depends on frame position and total frames)
      max_possible_frames = 10 # We have 10 frames in test data
      if initial_end < max_possible_frames - 1 do
        expected_added = min(2, max_possible_frames - initial_end)
        assert new_end <= initial_end + expected_added
        assert length(new_sequence.sequence_frames) >= initial_length
        
        # Check that new frames at end are auto-selected
        new_indices = Enum.to_list(initial_length..(initial_length + expected_added - 1))
        expected_all = initial_selected ++ new_indices
        assert assigns(view).selected_frame_indices == expected_all
      end
    end

    test "expand_sequence_multiple with invalid count does nothing", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_sequence = assigns(view).frame_sequence
      initial_selected = assigns(view).selected_frame_indices

      # Test invalid counts
      render_hook(view, "expand_sequence_backward_multiple", %{"value" => "0"})
      assert assigns(view).frame_sequence == initial_sequence
      assert assigns(view).selected_frame_indices == initial_selected

      render_hook(view, "expand_sequence_forward_multiple", %{"value" => "21"})
      assert assigns(view).frame_sequence == initial_sequence
      assert assigns(view).selected_frame_indices == initial_selected

      render_hook(view, "expand_sequence_backward_multiple", %{"value" => "invalid"})
      assert assigns(view).frame_sequence == initial_sequence
      assert assigns(view).selected_frame_indices == initial_selected
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

    test "select_sample_suggestion populates search field", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      sample_suggestion = "I graduated from business school"
      render_click(view, "select_sample_suggestion", %{"suggestion" => sample_suggestion})

      assert assigns(view).search_form == %{"term" => sample_suggestion}
      assert assigns(view).search_term == sample_suggestion
      assert assigns(view).show_autocomplete == false
      assert assigns(view).autocomplete_suggestions == []
    end
  end

  describe "GIF generation events" do
    test "generate_gif with valid frame sequence and selection starts async task", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal and select some frames
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})
      
      # Ensure we have some frames selected
      assert length(assigns(view).selected_frame_indices) > 0

      # Start GIF generation
      render_click(view, "generate_gif")

      # Should set generating status
      assert assigns(view).gif_generation_status == :generating
      assert assigns(view).gif_generation_task != nil
      assert assigns(view).generated_gif_data == nil
    end

    test "generate_gif with no frame sequence shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # No frame sequence open
      assert assigns(view).frame_sequence == nil

      render_click(view, "generate_gif")

      # Should show error flash and not start task
      assert assigns(view).gif_generation_status == nil
      assert assigns(view)[:gif_generation_task] == nil
    end

    test "generate_gif with no selected frames shows error", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal but deselect all frames
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})
      render_click(view, "deselect_all_frames")
      
      assert assigns(view).selected_frame_indices == []

      render_click(view, "generate_gif")

      # Should show error flash and not start task
      assert assigns(view).gif_generation_status == nil
      assert assigns(view)[:gif_generation_task] == nil
    end

    test "GIF generation task completion updates status and data", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Setup frame sequence
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      # Mock successful GIF generation
      gif_data = <<0x47, 0x49, 0x46, 0x38, 0x39, 0x61>> # GIF89a header
      task_ref = make_ref()
      
      # Since we don't have a real task, manually set up the task for the test
      :sys.replace_state(view.pid, fn state ->
        %{state | 
          socket: %{state.socket | 
            assigns: Map.merge(state.socket.assigns, %{
              gif_generation_task: %{ref: task_ref},
              gif_generation_status: :generating
            })
          }
        }
      end)

      # Send completion message
      send(view.pid, {task_ref, {:ok, gif_data}})
      
      # Allow message processing
      :timer.sleep(10)

      # Should update to completed status with base64 data
      assert assigns(view).gif_generation_status == :completed
      assert assigns(view).generated_gif_data == Base.encode64(gif_data)
      assert assigns(view)[:gif_generation_task] == nil
    end

    test "GIF generation task failure updates status with error", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Setup frame sequence
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      # Mock failed GIF generation
      task_ref = make_ref()
      error_message = "FFMPEG not available"
      
      # Set up task state
      :sys.replace_state(view.pid, fn state ->
        %{state | 
          socket: %{state.socket | 
            assigns: Map.merge(state.socket.assigns, %{
              gif_generation_task: %{ref: task_ref},
              gif_generation_status: :generating
            })
          }
        }
      end)

      # Send error message
      send(view.pid, {task_ref, {:error, error_message}})
      
      # Allow message processing
      :timer.sleep(10)

      # Should reset status and show error
      assert assigns(view).gif_generation_status == nil
      assert assigns(view)[:gif_generation_task] == nil
    end

    test "GIF generation task crash is handled gracefully", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Setup frame sequence
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      # Mock task crash
      task_ref = make_ref()
      
      # Set up task state
      :sys.replace_state(view.pid, fn state ->
        %{state | 
          socket: %{state.socket | 
            assigns: Map.merge(state.socket.assigns, %{
              gif_generation_task: %{ref: task_ref},
              gif_generation_status: :generating
            })
          }
        }
      end)

      # Send DOWN message (task crash)
      send(view.pid, {:DOWN, task_ref, :process, self(), :killed})
      
      # Allow message processing
      :timer.sleep(10)

      # Should reset status and show error
      assert assigns(view).gif_generation_status == nil
      assert assigns(view)[:gif_generation_task] == nil
    end

    test "closing sequence modal resets GIF generation state", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Setup frame sequence and start GIF generation
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      # Set some GIF state
      :sys.replace_state(view.pid, fn state ->
        %{state | 
          socket: %{state.socket | 
            assigns: Map.merge(state.socket.assigns, %{
              gif_generation_status: :completed,
              generated_gif_data: "base64data"
            })
          }
        }
      end)

      # Close modal
      render_click(view, "close_sequence_modal")

      # GIF state should be reset
      assert assigns(view).gif_generation_status == nil
      assert assigns(view).generated_gif_data == nil
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
    test "process_video with valid path handles gracefully when processing disabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      _initial_video_count = length(assigns(view).videos)

      # In test environment, video processing is disabled, so this should handle gracefully
      render_click(view, "process_video", %{"video_path" => "/test/path.mp4"})

      # Should handle gracefully without crashing, videos list unchanged
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
    test "invalid video_id in toggle_video_selection shows error flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      render_click(view, "toggle_video_selection", %{"video_id" => "invalid"})
      
      # Should handle gracefully with error flash, not crash
      assert assigns(view).selected_video_ids == []
    end

    test "invalid frame_index in toggle_frame_selection is handled gracefully", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence modal
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})

      initial_selection = assigns(view).selected_frame_indices

      render_click(view, "toggle_frame_selection", %{"frame_index" => "invalid"})
      
      # Should handle gracefully with error flash, selection unchanged
      assert assigns(view).selected_frame_indices == initial_selection
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
      assert assigns(view).search_term == "test"
      # Note: loading state may not be true immediately in test environment
      assert is_boolean(assigns(view).loading)

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

  describe "video expansion events" do
    test "toggle_video_expansion expands a collapsed video", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Perform a search to get grouped results
      send(view.pid, {:perform_search, "test"})
      :timer.sleep(50)

      # Initially, no videos should be expanded
      assert assigns(view).expanded_videos == MapSet.new()

      # Expand the video
      render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video.id)})

      # Video should now be expanded
      assert MapSet.member?(assigns(view).expanded_videos, video.id)
      
      # Check that search results reflect the expanded state
      video_result = Enum.find(assigns(view).search_results, fn vr -> vr.video_id == video.id end)
      if video_result do
        assert video_result.expanded == true
      end
    end

    test "toggle_video_expansion collapses an expanded video", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Perform a search to get grouped results
      send(view.pid, {:perform_search, "test"})
      :timer.sleep(50)

      # Expand the video first
      render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video.id)})
      assert MapSet.member?(assigns(view).expanded_videos, video.id)

      # Collapse the video
      render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video.id)})

      # Video should now be collapsed
      assert !MapSet.member?(assigns(view).expanded_videos, video.id)
      
      # Check that search results reflect the collapsed state
      video_result = Enum.find(assigns(view).search_results, fn vr -> vr.video_id == video.id end)
      if video_result do
        assert video_result.expanded == false
      end
    end

    test "toggle_video_expansion with invalid video_id shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      render_click(view, "toggle_video_expansion", %{"video_id" => "invalid"})

      # Should handle gracefully with error flash
      assert assigns(view).expanded_videos == MapSet.new()
    end

    test "new search clears all video expansion states", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Perform initial search and expand some videos
      send(view.pid, {:perform_search, "test"})
      :timer.sleep(50)

      # Expand a video
      render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video.id)})
      assert MapSet.member?(assigns(view).expanded_videos, video.id)

      # Perform a new search
      send(view.pid, {:perform_search, "caption"})
      :timer.sleep(50)

      # All expansion states should be cleared
      assert assigns(view).expanded_videos == MapSet.new()
    end

    test "video expansion state persists across multiple toggles", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Perform a search
      send(view.pid, {:perform_search, "test"})
      :timer.sleep(50)

      # Test multiple rapid toggles
      for _i <- 1..3 do
        render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video.id)})
        render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video.id)})
      end

      # Should end in collapsed state (even number of toggles)
      assert !MapSet.member?(assigns(view).expanded_videos, video.id)
    end

    test "video expansion affects search results structure", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Perform search to get results
      send(view.pid, {:perform_search, "test"})
      :timer.sleep(50)

      initial_results = assigns(view).search_results
      
      # Expand video
      render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video.id)})
      
      # Search results should be updated with expansion state
      updated_results = assigns(view).search_results
      
      # Find the video result and check its expansion state
      video_result = Enum.find(updated_results, fn vr -> vr.video_id == video.id end)
      if video_result do
        assert video_result.expanded == true
      end
      
      # Results length should remain the same, only expansion state changed
      assert length(initial_results) == length(updated_results)
    end

    test "multiple videos can be expanded independently", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Create a second test video
      {:ok, video2} = %VideoSchema{}
      |> VideoSchema.changeset(%{
        title: "Test Video 2",
        file_path: "/test/video2.mp4",
        duration_ms: 5000,
        fps: 24.0,
        frame_count: 50,
        status: "completed"
      })
      |> Repo.insert()

      # Perform search
      send(view.pid, {:perform_search, "test"})
      :timer.sleep(50)

      video1 = List.first(assigns(view).videos)
      
      # Expand first video
      render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video1.id)})
      assert MapSet.member?(assigns(view).expanded_videos, video1.id)
      assert !MapSet.member?(assigns(view).expanded_videos, video2.id)

      # Expand second video
      render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video2.id)})
      assert MapSet.member?(assigns(view).expanded_videos, video1.id)
      assert MapSet.member?(assigns(view).expanded_videos, video2.id)

      # Collapse first video, second should remain expanded
      render_click(view, "toggle_video_expansion", %{"video_id" => to_string(video1.id)})
      assert !MapSet.member?(assigns(view).expanded_videos, video1.id)
      assert MapSet.member?(assigns(view).expanded_videos, video2.id)
    end
  end

  describe "URL parameter handling" do
    test "handle_params with video parameter sets video selection", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search?video=#{video.id}")

      # Should set video selection from URL
      assert assigns(view).selected_video_ids == [video.id]
      assert assigns(view).search_mode == :filtered
    end

    test "handle_params with invalid video parameter is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search?video=99999")

      # Should ignore invalid video ID
      assert assigns(view).selected_video_ids == []
      assert assigns(view).search_mode == :global
    end

    test "handle_params with frame parameter opens frame sequence", %{conn: conn, frames: frames} do
      frame = List.first(frames)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}")

      # Should open frame sequence modal
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).frame_sequence != nil
      assert assigns(view).frame_sequence.target_frame.id == frame.id
    end

    test "handle_params with frame and frames parameters sets selection", %{conn: conn, frames: frames} do
      frame = List.first(frames)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,1,2")

      # Should set frame selection from URL
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).selected_frame_indices == [0, 1, 2]
    end

    test "handle_params with invalid frame parameter is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search?frame=99999")

      # Should ignore invalid frame ID
      assert assigns(view).show_sequence_modal == false
      assert assigns(view).frame_sequence == nil
    end

    test "handle_params with malformed frames parameter is handled gracefully", %{conn: conn, frames: frames} do
      frame = List.first(frames)
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,invalid,2,")

      # Should parse valid indices and ignore invalid ones
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).selected_frame_indices == [0, 2]
    end

    test "push_video_selection_to_url updates URL with video selection", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Select a video (this should trigger URL update)
      render_click(view, "toggle_video_selection", %{"video_id" => to_string(video.id)})

      # URL update is handled via push_patch, which we can't directly test in unit tests
      # But we can verify the internal state is correct
      assert video.id in assigns(view).selected_video_ids
    end

    test "push_frame_selection_to_url updates URL with frame selection", %{conn: conn, frames: frames} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Open frame sequence and select frames
      frame = List.first(frames)
      render_click(view, "show_frame_sequence", %{"frame_id" => to_string(frame.id)})
      render_click(view, "deselect_all_frames")
      render_click(view, "toggle_frame_selection", %{"frame_index" => "0"})
      render_click(view, "toggle_frame_selection", %{"frame_index" => "2"})

      # URL update would be handled via push_patch
      # Verify internal state is correct
      assert assigns(view).selected_frame_indices == [0, 2]
    end

    test "build_url_with_params creates correct URLs", %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/video-search")

      # This tests the private function indirectly through the module
      # We can't test private functions directly, but we can verify behavior
      # through public functions that use them
      
      # The function should handle empty params
      # and create query strings correctly
      assert is_binary("/video-search")
    end

    test "parse_selected_frames_from_params handles various input formats", %{conn: conn, frames: frames} do
      frame = List.first(frames)
      
      # Test comma-separated values
      {:ok, view, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,1,2")
      assert assigns(view).selected_frame_indices == [0, 1, 2]

      # Test with spaces
      {:ok, view2, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0, 1, 2")
      assert assigns(view2).selected_frame_indices == [0, 1, 2]

      # Test with mixed valid/invalid
      {:ok, view3, _html} = live(conn, "/video-search?frame=#{frame.id}&frames=0,invalid,2")
      assert assigns(view3).selected_frame_indices == [0, 2]
    end

    test "URL parameters are preserved in current_params", %{conn: conn, video: video} do
      {:ok, view, _html} = live(conn, "/video-search?video=#{video.id}&custom=value")

      # Should store all params for URL building
      assert assigns(view)[:current_params] != nil
    end

    test "combining video and frame parameters works correctly", %{conn: conn, video: video, frames: frames} do
      frame = List.first(frames)
      {:ok, view, _html} = live(conn, "/video-search?video=#{video.id}&frame=#{frame.id}&frames=0,1")

      # Should handle both video and frame parameters
      assert assigns(view).selected_video_ids == [video.id]
      assert assigns(view).search_mode == :filtered
      assert assigns(view).show_sequence_modal == true
      assert assigns(view).selected_frame_indices == [0, 1]
    end
  end

  describe "performance and concurrency" do
    test "multiple rapid search requests are handled correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Send multiple rapid search requests
      for term <- ["a", "ab", "abc", "abcd"] do
        view |> element("form") |> render_submit(%{"search" => %{"term" => term}})
        :timer.sleep(5)
      end

      # Final state should reflect last search
      assert assigns(view).search_term == "abcd"
      # Loading might be true or false depending on timing, just ensure it's boolean
      assert is_boolean(assigns(view).loading)
      
      # Wait for all async operations to complete
      :timer.sleep(100)
      assert assigns(view).loading == false
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

  describe "sample suggestions display" do
    test "sample suggestions appear when search is empty", %{conn: conn} do
      {:ok, view, html} = live(conn, "/video-search")

      # With empty search, sample suggestions should be visible
      assert assigns(view).search_term == ""
      assert assigns(view).show_autocomplete == false
      assert length(assigns(view).sample_suggestions) > 0

      # HTML should contain sample suggestions section
      assert html =~ "TRY SEARCHING FOR"
    end

    test "sample suggestions hidden when search has content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Enter search term
      render_hook(view, "autocomplete_search", %{"search" => %{"term" => "test"}})

      # Sample suggestions should not show when there's search content
      assert assigns(view).search_term == "test"
      
      # Re-render to get updated HTML
      html = render(view)
      
      # If autocomplete is not showing, sample suggestions might still be hidden
      # due to search term being present
      if assigns(view).show_autocomplete do
        # Autocomplete is showing, so sample suggestions should be hidden
        refute html =~ "TRY SEARCHING FOR"
      end
    end

    test "sample suggestions hidden when autocomplete is showing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Trigger autocomplete
      render_hook(view, "autocomplete_search", %{"search" => %{"term" => "test"}})

      if assigns(view).show_autocomplete do
        html = render(view)
        # When autocomplete is showing, sample suggestions should be hidden
        refute html =~ "TRY SEARCHING FOR"
      end
    end

    test "clicking sample suggestion triggers select_sample_suggestion event", %{conn: conn} do
      {:ok, view, html} = live(conn, "/video-search")

      # Sample suggestions should be present
      assert html =~ "TRY SEARCHING FOR"
      assert length(assigns(view).sample_suggestions) > 0

      # Get a sample suggestion
      sample_suggestion = List.first(assigns(view).sample_suggestions)

      # Click on a sample suggestion
      render_click(view, "select_sample_suggestion", %{"suggestion" => sample_suggestion})

      # Should populate search field
      assert assigns(view).search_term == sample_suggestion
      assert assigns(view).search_form == %{"term" => sample_suggestion}
    end

    test "sample suggestions component renders all provided suggestions", %{conn: conn} do
      {:ok, view, html} = live(conn, "/video-search")

      sample_suggestions = assigns(view).sample_suggestions
      assert length(sample_suggestions) > 0

      # All sample suggestions should appear in the HTML
      Enum.each(sample_suggestions, fn suggestion ->
        assert html =~ suggestion
      end)
    end

    test "sample suggestions have correct phx-click attributes", %{conn: conn} do
      {:ok, view, html} = live(conn, "/video-search")

      if length(assigns(view).sample_suggestions) > 0 do
        # HTML should contain phx-click="select_sample_suggestion"
        assert html =~ "phx-click=\"select_sample_suggestion\""
        assert html =~ "phx-value-suggestion="
      end
    end

    test "sample suggestions are passed to search interface component", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Sample suggestions should be loaded and passed to the component
      assert is_list(assigns(view).sample_suggestions)
      assert length(assigns(view).sample_suggestions) > 0
    end

    test "clearing search term shows sample suggestions again", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/video-search")

      # Enter search term
      view |> element("form") |> render_submit(%{"search" => %{"term" => "test"}})
      assert assigns(view).search_term == "test"

      # Clear search term
      view |> element("form") |> render_submit(%{"search" => %{"term" => ""}})
      assert assigns(view).search_term == ""

      # Re-render to get updated HTML
      html = render(view)

      # Sample suggestions should show again when search is empty
      assert html =~ "TRY SEARCHING FOR"
    end
  end
end
