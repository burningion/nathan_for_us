# URL Functionality Test Guide

## Test the URL encoding functionality manually:

### 1. Video Selection URL Encoding
- Go to `/video-search`
- Open video filter modal
- Select a video
- Apply filter
- **Expected**: URL should update to `/video-search?video=<video_id>`
- Refresh page
- **Expected**: Video should remain selected

### 2. Frame Selection URL Encoding
- Go to `/video-search`
- Search for any term that returns results
- Click on a frame to open sequence modal
- **Expected**: URL should update to `/video-search?frame=<frame_id>&frames=<selected_indices>`
- Select/deselect individual frames
- **Expected**: URL should update with new frame selection
- Refresh page
- **Expected**: Frame modal should reopen with same selection

### 3. Frame Sequence Expansion URL Encoding
- Open any frame sequence
- Click "Expand Backward" or "Expand Forward"
- **Expected**: URL should update with new frame indices
- Use multi-frame expansion controls
- **Expected**: URL should update each time frames are added

### 4. Combined Video + Frame URL Encoding
- Select a video first
- Then open a frame sequence
- **Expected**: URL should contain both video and frame parameters like:
  `/video-search?video=<video_id>&frame=<frame_id>&frames=<indices>`

### 5. URL Sharing Test
- Copy a URL with both video and frame parameters
- Open in new tab/window
- **Expected**: Page should load with correct video filter and frame modal open

All URL updates now happen immediately when:
- Video selection changes
- Frame sequence opens/closes
- Individual frames are selected/deselected
- Frame sequences are expanded (backward/forward)
- Multiple frame expansion operations