# Complete YouTube to Production Pipeline Guide

## Prerequisites

### 1. Install yt-dlp via Python/ASDF
```bash
# yt-dlp is available through pip in asdf python
pip install yt-dlp

# Verify installation
which yt-dlp
# Should show: /Users/[user]/.asdf/shims/yt-dlp
```

### 2. FFmpeg with Hardware Acceleration
```bash
# Install via Homebrew with VideoToolbox support
brew install ffmpeg
```

### 3. Phoenix Application Running
The video processing requires the Phoenix application to be running for the GenStage pipeline.

## Complete Process: YouTube URL → Production

### Step 1: Download Video and Captions
```bash
# Use yt-dlp to download video with captions
/Users/robertgrayson/.asdf/shims/yt-dlp \
  -f "best[height<=720]" \
  --write-sub \
  --write-auto-sub \
  --sub-lang en \
  --convert-subs srt \
  -o "downloads/%(title)s.%(ext)s" \
  "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Step 2: Process Video Locally
With Phoenix application running (`iex -S mix`):

```elixir
# Queue video for processing through GenStage pipeline
video_path = "downloads/[VIDEO_TITLE].mp4"
{:ok, video} = NathanForUs.VideoProcessing.process_video(video_path)

# Alternative: Manual processing if GenStage fails
# 1. Create video record
{:ok, video} = NathanForUs.Video.create_video(%{
  title: "Video Title",
  file_path: video_path,
  status: "pending"
})

# 2. Process frames manually
config = NathanForUs.VideoProcessor.new(video_path, store_binary: true, fps: 1)
frames = NathanForUs.VideoProcessor.extract_frames_as_binary(config)

# 3. Process captions
caption_path = String.replace(video_path, ".mp4", ".en.srt")
{:ok, captions} = NathanForUs.SrtParser.parse_file(caption_path)

# 4. Store in database with frame-caption linking
# This requires running the full processing pipeline
```

### Step 3: Verify Local Processing
```sql
-- Check video was processed successfully
SELECT id, title, status, frame_count FROM videos WHERE status = 'completed';

-- Verify frames and captions
SELECT 
  v.title,
  COUNT(vf.id) as frame_count,
  COUNT(vc.id) as caption_count,
  COUNT(fc.id) as link_count
FROM videos v
LEFT JOIN video_frames vf ON v.id = vf.video_id
LEFT JOIN video_captions vc ON v.id = vc.video_id  
LEFT JOIN frame_captions fc ON vf.id = fc.frame_id
WHERE v.id = [VIDEO_ID]
GROUP BY v.id, v.title;
```

### Step 4: Sync to Production (Complete Database Dump)
```bash
# Create complete database dump
pg_dump -h localhost -U postgres -d nathan_for_us_dev \
  --no-owner --no-privileges --clean --if-exists \
  > /tmp/complete_db_dump.sql

# Upload to production via Gigalixir
gigalixir pg:psql < /tmp/complete_db_dump.sql

# Clean up large dump file
rm /tmp/complete_db_dump.sql
```

### Step 5: Verify Production
```bash
# Test search functionality
echo "SELECT 
  v.id, 
  v.title, 
  COUNT(vf.id) as frame_count,
  COUNT(CASE WHEN vf.image_data IS NOT NULL THEN 1 END) as frames_with_images
FROM videos v 
LEFT JOIN video_frames vf ON v.id = vf.video_id 
GROUP BY v.id, v.title 
ORDER BY v.id;" > /tmp/verify_production.sql

gigalixir pg:psql < /tmp/verify_production.sql

# Test specific search
echo "SELECT COUNT(*) as search_results
FROM video_frames vf
WHERE vf.video_id = [NEW_VIDEO_ID]
  AND EXISTS (
    SELECT 1 FROM frame_captions fc 
    JOIN video_captions vc ON fc.caption_id = vc.id 
    WHERE fc.frame_id = vf.id 
      AND vc.text ILIKE '%[SEARCH_TERM]%'
  );" > /tmp/test_search.sql

gigalixir pg:psql < /tmp/test_search.sql
```

## Automation Script Usage

### Process New Video End-to-End
```bash
# Update script path for yt-dlp first
elixir scripts/complete_video_sync.exs "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Sync Only (if video already processed locally)
```bash
elixir scripts/complete_video_sync.exs sync_only [VIDEO_ID]
```

## Troubleshooting

### Common Issues

1. **yt-dlp not found**: Update script to use full path `/Users/[user]/.asdf/shims/yt-dlp`

2. **GenStage processing fails**: Process manually using VideoProcessor functions

3. **Binary data encoding issues**: Use complete pg_dump approach instead of selective sync

4. **Search not working**: Verify frame-caption links exist and are properly associated

### Key Files to Monitor
- `downloads/` - Downloaded videos and captions
- `priv/static/frames/` - Extracted frame images (if not using binary storage)
- Video database tables: `videos`, `video_frames`, `video_captions`, `frame_captions`

## Production URLs
- Video Search Interface: https://www.nathanforus.com/video-search
- Admin Interface: https://www.nathanforus.com/admin

## Success Criteria
✅ Video appears in production database  
✅ All frames have binary image_data  
✅ All captions are searchable  
✅ Frame-caption associations exist  
✅ Search interface returns results with images  
✅ Production site is responsive and functional