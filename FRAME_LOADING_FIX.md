# Frame Loading Fix for Shared URLs

## Problem
When sharing URLs with specific frame selections (e.g., `/video-search?frame=123&frames=2,5,8`), frames outside the default view range would not load properly and appear as black in animations.

## Root Cause
The `get_frame_sequence/2` function in `lib/nathan_for_us/video.ex` only loads frames within a default range (±5 frames around the target frame). When URLs contain selected frame indices that reference frames outside this range, those frames are not loaded from the database, causing them to appear as black in animations.

## Solution
Added a new function `get_frame_sequence_with_selected_indices/3` that:

1. **Analyzes selected frame indices** from the URL parameters
2. **Calculates an expanded frame range** to ensure all selected frames are covered
3. **Loads all necessary frames** from the database to prevent black frames in animations

### Key Changes

#### 1. New Function in `lib/nathan_for_us/video.ex`
```elixir
def get_frame_sequence_with_selected_indices(frame_id, selected_indices, base_sequence_length \\ 5)
```

This function:
- Takes the target frame ID and selected indices as parameters
- Calculates the minimum range needed to cover all selected frames
- Loads frames from the database with the expanded range
- Returns the same structure as the original function

#### 2. Updated LiveView Handler in `lib/nathan_for_us_web/live/video_search_live.ex`
```elixir
defp handle_frame_selection_from_params(socket, params) do
  # Parse selected frames from URL first
  selected_indices = parse_selected_frames_from_params(params)
  
  # Use the new function that ensures all selected frames are loaded
  frame_sequence_result = if Enum.empty?(selected_indices) do
    Video.get_frame_sequence(frame_id)
  else
    Video.get_frame_sequence_with_selected_indices(frame_id, selected_indices)
  end
  
  # ... rest of the handler
end
```

#### 3. Helper Function for Range Calculation
```elixir
defp calculate_range_for_selected_indices(target_frame_number, selected_indices, base_sequence_length)
```

This helper:
- Determines the frame range needed based on selected indices
- Ensures the range covers both the default sequence and all selected frames
- Handles edge cases like empty selections or extreme indices

## How It Works

### Before the Fix
1. User shares URL: `/video-search?frame=100&frames=0,5,12`
2. System loads default range around frame 100 (frames 95-105)
3. Selected indices [0,5,12] map to frames 95, 100, 107
4. Frame 107 is outside the loaded range → appears black

### After the Fix
1. User shares URL: `/video-search?frame=100&frames=0,5,12`
2. System analyzes selected indices and calculates needed range
3. System loads expanded range (frames 95-107) to cover all selections
4. All selected frames are properly loaded → no black frames

## Testing
Created comprehensive tests to verify:
- ✅ Default behavior when no selected indices provided
- ✅ Range expansion for indices outside default range
- ✅ Graceful handling of extreme indices
- ✅ Single frame selection scenarios

## Backward Compatibility
- Original `get_frame_sequence/2` function remains unchanged
- Existing functionality continues to work as before
- New function only used when URL parameters contain frame selections

## Benefits
1. **Fixed shared URL issue**: Frames no longer appear black in shared animations
2. **Improved user experience**: Shared URLs work exactly as intended
3. **Maintainable solution**: Clean separation between default and URL-based loading
4. **Performance optimized**: Only loads additional frames when necessary