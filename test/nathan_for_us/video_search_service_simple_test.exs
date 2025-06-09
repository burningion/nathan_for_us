defmodule NathanForUs.VideoSearchServiceSimpleTest do
  use ExUnit.Case, async: true
  
  alias NathanForUs.VideoSearchService
  
  describe "search_frames/3" do
    test "returns empty results for empty search term" do
      assert {:ok, []} = VideoSearchService.search_frames("", :global, [])
      assert {:ok, []} = VideoSearchService.search_frames("", :filtered, [1, 2])
    end
    
    test "returns empty results for filtered search with no selected videos" do
      assert {:ok, []} = VideoSearchService.search_frames("test", :filtered, [])
    end
  end
  
  describe "process_video/1" do
    test "rejects empty video path" do
      assert {:error, "Video path cannot be empty"} = 
        VideoSearchService.process_video("")
      
      assert {:error, "Video path cannot be empty"} = 
        VideoSearchService.process_video(nil)
    end
    
    test "rejects non-existent video file" do
      assert {:error, "Video file does not exist: /nonexistent/video.mp4"} = 
        VideoSearchService.process_video("/nonexistent/video.mp4")
    end
  end
  
  describe "update_video_filter/2" do
    test "adds video to empty selection" do
      result = VideoSearchService.update_video_filter([], 1)
      assert result == [1]
    end
    
    test "adds video to existing selection" do
      result = VideoSearchService.update_video_filter([1, 2], 3)
      assert result == [3, 1, 2]
    end
    
    test "removes video from selection" do
      result = VideoSearchService.update_video_filter([1, 2, 3], 2)
      assert result == [1, 3]
    end
    
    test "handles removing non-existent video" do
      result = VideoSearchService.update_video_filter([1, 2], 3)
      assert result == [3, 1, 2]
    end
  end
  
  describe "determine_search_mode/1" do
    test "returns global for empty selection" do
      assert :global = VideoSearchService.determine_search_mode([])
    end
    
    test "returns filtered for non-empty selection" do
      assert :filtered = VideoSearchService.determine_search_mode([1])
      assert :filtered = VideoSearchService.determine_search_mode([1, 2, 3])
    end
  end
  
  describe "get_search_status/3" do
    test "returns global search status" do
      all_videos = [%{id: 1}, %{id: 2}, %{id: 3}]
      
      result = VideoSearchService.get_search_status(:global, [], all_videos)
      
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
      
      result = VideoSearchService.get_search_status(:filtered, selected_ids, all_videos)
      
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
      result = VideoSearchService.toggle_frame_selection([], 1)
      assert result == [1]
    end
    
    test "adds frame to existing selection and sorts" do
      result = VideoSearchService.toggle_frame_selection([1, 3], 2)
      assert result == [1, 2, 3]
    end
    
    test "removes frame from selection" do
      result = VideoSearchService.toggle_frame_selection([1, 2, 3], 2)
      assert result == [1, 3]
    end
  end
  
  describe "get_all_frame_indices/1" do
    test "returns correct indices for frame sequence" do
      frame_sequence = %{
        sequence_frames: [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}]
      }
      
      result = VideoSearchService.get_all_frame_indices(frame_sequence)
      assert result == [0, 1, 2, 3]
    end
    
    test "returns empty list for empty sequence" do
      frame_sequence = %{sequence_frames: []}
      
      result = VideoSearchService.get_all_frame_indices(frame_sequence)
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
      
      result = VideoSearchService.get_selected_frames_captions(frame_sequence, selected_indices)
      assert result == "Hello there !"
    end
    
    test "handles frames with no captions" do
      frame_sequence = %{
        sequence_frames: [%{id: 1}, %{id: 2}],
        sequence_captions: %{1 => ["Hello"]}
      }
      
      selected_indices = [1]  # frame 2 has no captions
      
      result = VideoSearchService.get_selected_frames_captions(frame_sequence, selected_indices)
      assert result == "No dialogue found for selected frames"
    end
    
    test "handles missing sequence_captions" do
      frame_sequence = %{
        sequence_frames: [%{id: 1}, %{id: 2}]
      }
      
      result = VideoSearchService.get_selected_frames_captions(frame_sequence, [0, 1])
      assert result == "Loading captions..."
    end
    
    test "handles nil frame sequence" do
      result = VideoSearchService.get_selected_frames_captions(nil, [0, 1])
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
      
      result = VideoSearchService.get_selected_frames_captions(frame_sequence, selected_indices)
      assert result == "Hello World !"
    end
  end
end