defmodule NathanForUs.SearchSimpleTest do
  use ExUnit.Case, async: true
  
  alias NathanForUs.Video.Search
  
  describe "search_frames/3" do
    test "returns empty results for empty search term" do
      assert {:ok, []} = Search.search_frames("", :global, [])
      assert {:ok, []} = Search.search_frames("", :filtered, [1, 2])
    end
    
    test "returns empty results for filtered search with no selected videos" do
      assert {:ok, []} = Search.search_frames("test", :filtered, [])
    end
  end
  
  
  describe "update_video_filter/2" do
    test "adds video to empty selection" do
      result = Search.update_video_filter([], 1)
      assert result == [1]
    end
    
    test "adds video to existing selection" do
      result = Search.update_video_filter([1, 2], 3)
      assert result == [3, 1, 2]
    end
    
    test "removes video from selection" do
      result = Search.update_video_filter([1, 2, 3], 2)
      assert result == [1, 3]
    end
    
    test "handles removing non-existent video" do
      result = Search.update_video_filter([1, 2], 3)
      assert result == [3, 1, 2]
    end
  end
  
  describe "determine_search_mode/1" do
    test "returns global for empty selection" do
      assert :global = Search.determine_search_mode([])
    end
    
    test "returns filtered for non-empty selection" do
      assert :filtered = Search.determine_search_mode([1])
      assert :filtered = Search.determine_search_mode([1, 2, 3])
    end
  end
  
  describe "get_search_status/3" do
    test "returns global search status" do
      all_videos = [%{id: 1}, %{id: 2}, %{id: 3}]
      
      result = Search.get_search_status(:global, [], all_videos)
      
      assert result == %{
        mode: :global,
        message: "Searching across all 3 videos",
        selected_count: 0,
        total_count: 3
      }
    end
    
    test "returns filtered search status" do
      all_videos = [%{id: 1}, %{id: 2}, %{id: 3}]
      selected_ids = [1, 3]
      
      result = Search.get_search_status(:filtered, selected_ids, all_videos)
      
      assert result == %{
        mode: :filtered,
        message: "Filtering 2 of 3 videos",
        selected_count: 2,
        total_count: 3
      }
    end
  end
  
  describe "toggle_frame_selection/2" do
    test "adds frame to empty selection" do
      result = Search.toggle_frame_selection([], 1)
      assert result == [1]
    end
    
    test "adds frame to existing selection and sorts" do
      result = Search.toggle_frame_selection([1, 3], 2)
      assert result == [1, 2, 3]
    end
    
    test "removes frame from selection" do
      result = Search.toggle_frame_selection([1, 2, 3], 2)
      assert result == [1, 3]
    end
  end
  
  describe "get_all_frame_indices/1" do
    test "returns correct indices for frame sequence" do
      frame_sequence = %{
        sequence_frames: [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}]
      }
      
      result = Search.get_all_frame_indices(frame_sequence)
      assert result == [0, 1, 2, 3]
    end
    
    test "returns empty list for empty sequence" do
      frame_sequence = %{sequence_frames: []}
      
      result = Search.get_all_frame_indices(frame_sequence)
      assert result == []
    end
  end
  
  describe "get_selected_frames_captions/2" do
    test "concatenates captions from selected frames" do
      frame_sequence = %{
        sequence_frames: [
          %{id: 1}, %{id: 2}, %{id: 3}
        ],
        sequence_captions: %{
          1 => ["Hello", "there"],
          2 => ["World"],
          3 => ["!"]
        }
      }
      
      selected_indices = [0, 2]  # frames 1 and 3
      
      result = Search.get_selected_frames_captions(frame_sequence, selected_indices)
      assert result == "Hello there !"
    end
    
    test "handles frames with no captions" do
      frame_sequence = %{
        sequence_frames: [%{id: 1}, %{id: 2}],
        sequence_captions: %{1 => ["Hello"]}
      }
      
      selected_indices = [1]  # frame 2 has no captions
      
      result = Search.get_selected_frames_captions(frame_sequence, selected_indices)
      assert result == "No dialogue found for selected frames"
    end
    
    test "handles missing sequence_captions" do
      frame_sequence = %{
        sequence_frames: [%{id: 1}, %{id: 2}]
      }
      
      result = Search.get_selected_frames_captions(frame_sequence, [0, 1])
      assert result == "Loading captions..."
    end
    
    test "handles nil frame sequence" do
      result = Search.get_selected_frames_captions(nil, [0, 1])
      assert result == "Loading captions..."
    end
    
    test "filters out empty and nil captions" do
      frame_sequence = %{
        sequence_frames: [%{id: 1}, %{id: 2}, %{id: 3}],
        sequence_captions: %{
          1 => ["Hello", nil, ""],
          2 => ["World", "   "],
          3 => ["!"]
        }
      }
      
      selected_indices = [0, 1, 2]
      
      result = Search.get_selected_frames_captions(frame_sequence, selected_indices)
      assert result == "Hello World !"
    end
  end
  
  describe "group_frames_by_video/1" do
    test "groups frames by video correctly" do
      frames = [
        %{id: 1, video_id: 1, video_title: "Video A", timestamp_ms: 1000},
        %{id: 2, video_id: 2, video_title: "Video B", timestamp_ms: 2000},
        %{id: 3, video_id: 1, video_title: "Video A", timestamp_ms: 3000},
        %{id: 4, video_id: 3, video_title: "Video C", timestamp_ms: 4000},
        %{id: 5, video_id: 2, video_title: "Video B", timestamp_ms: 5000}
      ]
      
      result = Search.group_frames_by_video(frames)
      
      # Should return 3 video groups
      assert length(result) == 3
      
      # Find each video group
      video_a = Enum.find(result, fn vr -> vr.video_id == 1 end)
      video_b = Enum.find(result, fn vr -> vr.video_id == 2 end)
      video_c = Enum.find(result, fn vr -> vr.video_id == 3 end)
      
      # Verify Video A group
      assert video_a.video_title == "Video A"
      assert video_a.frame_count == 2
      assert length(video_a.frames) == 2
      assert video_a.expanded == false
      assert Enum.any?(video_a.frames, fn f -> f.id == 1 end)
      assert Enum.any?(video_a.frames, fn f -> f.id == 3 end)
      
      # Verify Video B group
      assert video_b.video_title == "Video B"
      assert video_b.frame_count == 2
      assert length(video_b.frames) == 2
      assert video_b.expanded == false
      assert Enum.any?(video_b.frames, fn f -> f.id == 2 end)
      assert Enum.any?(video_b.frames, fn f -> f.id == 5 end)
      
      # Verify Video C group
      assert video_c.video_title == "Video C"
      assert video_c.frame_count == 1
      assert length(video_c.frames) == 1
      assert video_c.expanded == false
      assert List.first(video_c.frames).id == 4
    end
    
    test "handles frames with missing video_title gracefully" do
      frames = [
        %{id: 1, video_id: 1, timestamp_ms: 1000},  # missing video_title key
        %{id: 2, video_id: 1, video_title: nil, timestamp_ms: 2000},  # nil video_title
        %{id: 3, video_id: 2, video_title: "Video B", timestamp_ms: 3000}
      ]
      
      result = Search.group_frames_by_video(frames)
      
      # Should group frames with missing/nil titles under "Unknown Video"
      assert length(result) == 2
      
      unknown_video = Enum.find(result, fn vr -> vr.video_title == "Unknown Video" end)
      video_b = Enum.find(result, fn vr -> vr.video_title == "Video B" end)
      
      assert unknown_video.video_id == 1
      assert unknown_video.frame_count == 2
      assert length(unknown_video.frames) == 2
      
      assert video_b.video_id == 2
      assert video_b.frame_count == 1
      assert length(video_b.frames) == 1
    end
    
    test "returns empty list for empty frames" do
      result = Search.group_frames_by_video([])
      assert result == []
    end
    
    test "handles single frame correctly" do
      frames = [
        %{id: 1, video_id: 42, video_title: "Single Video", timestamp_ms: 1000}
      ]
      
      result = Search.group_frames_by_video(frames)
      
      assert length(result) == 1
      video_group = List.first(result)
      
      assert video_group.video_id == 42
      assert video_group.video_title == "Single Video"
      assert video_group.frame_count == 1
      assert length(video_group.frames) == 1
      assert video_group.expanded == false
      assert List.first(video_group.frames).id == 1
    end
    
    test "sorts video groups by title" do
      frames = [
        %{id: 1, video_id: 1, video_title: "Zebra Video", timestamp_ms: 1000},
        %{id: 2, video_id: 2, video_title: "Apple Video", timestamp_ms: 2000},
        %{id: 3, video_id: 3, video_title: "Banana Video", timestamp_ms: 3000}
      ]
      
      result = Search.group_frames_by_video(frames)
      
      # Should be sorted alphabetically by title
      titles = Enum.map(result, & &1.video_title)
      assert titles == ["Apple Video", "Banana Video", "Zebra Video"]
    end
    
    test "preserves frame order within each video group" do
      frames = [
        %{id: 3, video_id: 1, video_title: "Video A", timestamp_ms: 3000, frame_number: 3},
        %{id: 1, video_id: 1, video_title: "Video A", timestamp_ms: 1000, frame_number: 1},
        %{id: 2, video_id: 1, video_title: "Video A", timestamp_ms: 2000, frame_number: 2}
      ]
      
      result = Search.group_frames_by_video(frames)
      
      assert length(result) == 1
      video_group = List.first(result)
      
      # Frames should maintain their original order (as returned by search query)
      frame_ids = Enum.map(video_group.frames, & &1.id)
      assert frame_ids == [3, 1, 2]
    end
    
    test "handles frames with same video_id but different video_title" do
      # This could happen due to data inconsistency
      frames = [
        %{id: 1, video_id: 1, video_title: "Video A", timestamp_ms: 1000},
        %{id: 2, video_id: 1, video_title: "Video A Modified", timestamp_ms: 2000}
      ]
      
      result = Search.group_frames_by_video(frames)
      
      # Should create separate groups for different titles even with same video_id
      assert length(result) == 2
      
      video_a = Enum.find(result, fn vr -> vr.video_title == "Video A" end)
      video_a_mod = Enum.find(result, fn vr -> vr.video_title == "Video A Modified" end)
      
      assert video_a.frame_count == 1
      assert video_a_mod.frame_count == 1
      assert List.first(video_a.frames).id == 1
      assert List.first(video_a_mod.frames).id == 2
    end
    
    test "all video groups start with expanded false" do
      frames = [
        %{id: 1, video_id: 1, video_title: "Video A", timestamp_ms: 1000},
        %{id: 2, video_id: 2, video_title: "Video B", timestamp_ms: 2000},
        %{id: 3, video_id: 3, video_title: "Video C", timestamp_ms: 3000}
      ]
      
      result = Search.group_frames_by_video(frames)
      
      # All videos should start collapsed
      assert Enum.all?(result, fn video_group -> video_group.expanded == false end)
    end
    
    test "preserves all frame data in grouped results" do
      frames = [
        %{
          id: 1, 
          video_id: 1, 
          video_title: "Video A", 
          timestamp_ms: 1000,
          frame_number: 42,
          file_path: "/path/to/frame.jpg",
          caption_texts: "Hello world"
        }
      ]
      
      result = Search.group_frames_by_video(frames)
      
      assert length(result) == 1
      video_group = List.first(result)
      frame = List.first(video_group.frames)
      
      # All original frame data should be preserved
      assert frame.id == 1
      assert frame.video_id == 1
      assert frame.video_title == "Video A"
      assert frame.timestamp_ms == 1000
      assert frame.frame_number == 42
      assert frame.file_path == "/path/to/frame.jpg"
      assert frame.caption_texts == "Hello world"
    end
  end
end