# KeyError Fix: selected_video_id

## Problem
When accessing `/video-search`, the application was throwing a KeyError:

```
KeyError at GET /video-search
key :selected_video_id not found in: %{loading: false, search_term: "", videos: [...]}
```

## Root Cause
During the conversion from video-specific search to global search, some template references to `@selected_video_id` were not fully removed. Specifically:

1. **Hidden form input**: `<input type="hidden" name="search[video_id]" value={@selected_video_id} />`
2. **Disabled conditions**: `disabled={is_nil(@selected_video_id)}` and `disabled={@loading or is_nil(@selected_video_id)}`

## Solution Applied

### 1. Removed Hidden Form Input ✅
```diff
- <input type="hidden" name="search[video_id]" value={@selected_video_id} />
```
This was unnecessary since global search doesn't require video_id parameter.

### 2. Updated Disabled Conditions ✅
```diff
# Search input field
- disabled={is_nil(@selected_video_id)}
+ (removed - always enabled now)

# Submit button  
- disabled={@loading or is_nil(@selected_video_id)}
+ disabled={@loading}
```

### 3. Removed State Assignment ✅
The `selected_video_id` was already removed from the mount function and state management, which was correct.

## Files Modified
- `lib/nathan_for_us_web/live/video_search_live.ex`

## Verification
✅ **Template compilation**: No more KeyError on page load  
✅ **Form functionality**: Search form works without video_id dependency  
✅ **Button states**: Submit button properly disabled only during loading  
✅ **Global search**: All functionality preserved from global search implementation  

## Testing Results
- **Page loads successfully** without KeyError
- **Search interface displays** with all 5 videos in database status
- **Global search functionality** remains intact
- **Video titles included** in search results as designed

The application now properly supports global search across all videos without any references to the removed video selector functionality.