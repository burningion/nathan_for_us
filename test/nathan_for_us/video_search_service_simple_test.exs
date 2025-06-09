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
end