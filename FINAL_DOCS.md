# Nathan For Us - Complete Video Processing & Search System

## Overview
This system processes YouTube videos frame-by-frame with captions to enable full-text search across Nathan Fielder interview content. Videos are broken down into individual frames with timestamped captions, stored in PostgreSQL, and made searchable through a Phoenix LiveView interface.

## Architecture

### Database Schema
```sql
-- Videos table - metadata about processed videos
CREATE TABLE videos (
  id SERIAL PRIMARY KEY,
  title VARCHAR NOT NULL,
  file_path VARCHAR NOT NULL UNIQUE,
  duration_ms INTEGER,
  fps FLOAT,
  frame_count INTEGER,
  status VARCHAR DEFAULT 'pending', -- pending, processing, completed, failed
  processed_at TIMESTAMP,
  metadata JSONB
);

-- Video frames - individual frame data
CREATE TABLE video_frames (
  id SERIAL PRIMARY KEY,
  video_id INTEGER REFERENCES videos(id) ON DELETE CASCADE,
  frame_number INTEGER NOT NULL,
  timestamp_ms INTEGER NOT NULL,
  file_path VARCHAR,
  file_size INTEGER,
  width INTEGER,
  height INTEGER,
  image_data BYTEA, -- Compressed JPEG binary data
  compression_ratio DOUBLE PRECISION
);

-- Video captions - subtitle/caption segments
CREATE TABLE video_captions (
  id SERIAL PRIMARY KEY,
  video_id INTEGER REFERENCES videos(id) ON DELETE CASCADE,
  start_time_ms INTEGER NOT NULL,
  end_time_ms INTEGER NOT NULL,
  text TEXT NOT NULL,
  caption_index INTEGER
);

-- Frame-caption associations - links frames to their captions
CREATE TABLE frame_captions (
  id SERIAL PRIMARY KEY,
  frame_id INTEGER REFERENCES video_frames(id) ON DELETE CASCADE,
  caption_id INTEGER REFERENCES video_captions(id) ON DELETE CASCADE
);

-- Full-text search index
CREATE INDEX video_captions_text_search_idx 
ON video_captions 
USING GIN (to_tsvector('english', text));
```

## Complete Process: YouTube URL to Production Search

### Automated Script Method (Recommended)

**Complete end-to-end processing:**
```bash
# Process new YouTube video from URL to production
elixir scripts/complete_video_sync.exs "https://youtube.com/watch?v=..." ["Custom Title"]

# Sync existing completed videos to production
elixir scripts/complete_video_sync.exs sync_only

# Sync specific video to production
elixir scripts/complete_video_sync.exs sync_only 4
```

**Utility commands:**
```bash
# Check system status
elixir scripts/video_utils.exs status

# Show production database statistics
elixir scripts/video_utils.exs stats

# Test search functionality
elixir scripts/video_utils.exs test_search 4 "train"

# List local videos
elixir scripts/video_utils.exs list_local

# Fix database sequences if needed
elixir scripts/video_utils.exs fix_sequence
```

### Manual Step-by-Step Method

### Step 1: Download YouTube Video

```bash
# Install yt-dlp if not already installed
pip install yt-dlp

# Download video with captions
yt-dlp -f 'best[height<=720]' --write-sub --write-auto-sub --sub-lang en --convert-subs srt "YOUTUBE_URL"

# This creates:
# - video_title.mp4 (video file)
# - video_title.en.srt (caption file)
```

### Step 2: Process Video Locally

1. **Start local development environment:**
```bash
cd nathan_for_us
mix deps.get
mix ecto.setup
mix phx.server
```

2. **Process the video through the system:**
```elixir
# In IEx console (iex -S mix)
video_path = "/path/to/your/video.mp4"
{:ok, video} = NathanForUs.VideoProcessing.process_video(video_path)
```

The processing pipeline automatically:
- Creates video record in database
- Extracts frames using FFmpeg at 1fps
- Parses SRT caption file
- Links frames to captions by timestamp
- Stores compressed JPEG data in database

### Step 3: Verify Local Processing

```elixir
# Check video status
video = NathanForUs.Video.get_video!(video_id)
IO.inspect(video.status) # Should be "completed"

# Check frame count
frame_stats = NathanForUs.Video.get_frame_stats(video.id)
IO.inspect(frame_stats)

# Check caption count  
caption_stats = NathanForUs.Video.get_caption_stats(video.id)
IO.inspect(caption_stats)

# Test search locally
results = NathanForUs.Video.search_frames_by_text_simple("train", video.id)
IO.inspect(length(results))
```

### Step 4: Export Data for Production

```bash
# Export frames without binary data to avoid encoding issues
PGPASSWORD=$(grep "password:" config/dev.exs | sed 's/.*password: "\([^"]*\)".*/\1/') \
psql -h localhost \
-U $(grep "username:" config/dev.exs | sed 's/.*username: "\([^"]*\)".*/\1/') \
-d $(grep "database:" config/dev.exs | sed 's/.*database: "\([^"]*\)".*/\1/') \
-t -c "SELECT 'INSERT INTO video_frames (video_id, frame_number, timestamp_ms, file_path, file_size, width, height, inserted_at, updated_at) VALUES (' || video_id || ',' || frame_number || ',' || timestamp_ms || ',''' || file_path || ''',' || COALESCE(file_size::text, 'NULL') || ',' || COALESCE(width::text, 'NULL') || ',' || COALESCE(height::text, 'NULL') || ', NOW(), NOW());' FROM video_frames WHERE video_id = VIDEO_ID;" > frames_export.sql
```

### Step 5: Deploy to Production

1. **Upload data to production database:**
```bash
gigalixir pg:psql < frames_export.sql
```

2. **Create frame-caption links:**
```bash
echo "
SELECT setval('frame_captions_id_seq', (SELECT COALESCE(MAX(id), 0) FROM frame_captions));
INSERT INTO frame_captions (frame_id, caption_id, inserted_at, updated_at)
SELECT DISTINCT f.id, c.id, NOW(), NOW()
FROM video_frames f
JOIN video_captions c ON f.video_id = c.video_id
WHERE f.timestamp_ms >= c.start_time_ms 
  AND f.timestamp_ms <= c.end_time_ms
  AND f.video_id = VIDEO_ID;
" | gigalixir pg:psql
```

3. **Verify production data:**
```bash
echo "SELECT id, title, status, frame_count FROM videos ORDER BY id DESC;" | gigalixir pg:psql
```

## Key Components

### Video Processing Pipeline (`lib/nathan_for_us/video_processing/`)

- **Producer**: Manages processing queue using GenStage
- **FrameExtractor**: Uses FFmpeg to extract frames at 1fps
- **CaptionParser**: Parses SRT files into timestamped segments
- **DatabaseConsumer**: Stores processed data in PostgreSQL

### Search Interface (`lib/nathan_for_us_web/live/video_search_live.ex`)

- **Video Selection**: Choose which video to search
- **Text Search**: Full-text search across captions
- **Frame Display**: Shows matching frames with timestamps
- **Image Rendering**: Displays compressed JPEG frames from database

### Core Video Context (`lib/nathan_for_us/video.ex`)

- **Database Operations**: CRUD for videos, frames, captions
- **Search Functions**: Text search with PostgreSQL full-text search
- **Batch Operations**: Efficient bulk inserts for frames/captions
- **Linking Logic**: Associates frames with captions by timestamp

## Search Query Examples

The search uses PostgreSQL ILIKE for simple text matching:

```sql
-- Find frames containing "train"
SELECT DISTINCT f.*, string_agg(DISTINCT c.text, ' | ') as caption_texts
FROM video_frames f
JOIN frame_captions fc ON fc.frame_id = f.id
JOIN video_captions c ON c.id = fc.caption_id
WHERE c.text ILIKE '%train%' AND f.video_id = ?
GROUP BY f.id, ...
ORDER BY f.timestamp_ms;
```

## Troubleshooting

### No Search Results
1. Check if video has frames: `SELECT COUNT(*) FROM video_frames WHERE video_id = ?`
2. Check if video has captions: `SELECT COUNT(*) FROM video_captions WHERE video_id = ?`
3. Check frame-caption links: `SELECT COUNT(*) FROM frame_captions fc JOIN video_frames f ON fc.frame_id = f.id WHERE f.video_id = ?`

### Image Display Issues
- Ensure `image_data` column contains compressed JPEG binary data
- Check `encode_image_data/1` function in LiveView for proper base64 encoding
- Verify hex data decoding using `String.slice(hex_data, 2..-1//1)`

### Production Sync Issues
- Use `gigalixir pg:psql` for direct database access
- Check migration status: `SELECT version FROM schema_migrations ORDER BY version DESC;`
- Verify table schemas match between local and production

## Configuration

### Local Development (`config/dev.exs`)
```elixir
config :nathan_for_us, NathanForUs.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "nathan_for_us_dev"
```

### Production (Gigalixir)
- Database managed through Gigalixir PostgreSQL addon
- Access via `gigalixir pg:psql`
- Deployments triggered by git push to main branch

## Performance Notes

- Videos processed at 1fps to balance search granularity with storage
- JPEG compression reduces storage requirements (~75% compression ratio)
- PostgreSQL GIN indexes enable fast full-text search
- Frame-caption linking enables precise timestamp-based search results

## Automation Scripts

### `scripts/complete_video_sync.exs`
Complete automation script that handles the entire pipeline from YouTube URL to production search functionality.

**Features:**
- Downloads YouTube videos with captions using yt-dlp
- Processes videos locally (frames + captions + linking)
- Exports data avoiding binary encoding issues
- Uploads to production database via gigalixir
- Creates frame-caption links
- Verifies search functionality

**Usage:**
```bash
# Full pipeline: URL to production
elixir scripts/complete_video_sync.exs "https://youtube.com/watch?v=abc123"

# With custom title
elixir scripts/complete_video_sync.exs "https://youtube.com/watch?v=abc123" "My Custom Title"

# Sync specific completed video
elixir scripts/complete_video_sync.exs sync_only 4

# Sync all completed videos
elixir scripts/complete_video_sync.exs sync_only
```

### `scripts/video_utils.exs`
Utility script for debugging, testing, and maintenance.

**Commands:**
```bash
# System overview
elixir scripts/video_utils.exs status

# Production database statistics
elixir scripts/video_utils.exs stats

# Test search functionality
elixir scripts/video_utils.exs test_search 4 "train"

# List local videos with details
elixir scripts/video_utils.exs list_local

# Fix database sequence issues
elixir scripts/video_utils.exs fix_sequence

# Check frame-caption link integrity
elixir scripts/video_utils.exs check_links 4
```

## File Structure
```
scripts/
├── complete_video_sync.exs    # End-to-end automation
└── video_utils.exs            # Debugging utilities

lib/nathan_for_us/
├── video.ex                    # Core video context
├── video_processing/           # Processing pipeline
│   ├── producer.ex            # GenStage producer
│   ├── frame_extractor.ex     # FFmpeg frame extraction
│   ├── caption_parser.ex      # SRT parsing
│   └── database_consumer.ex   # Data storage
├── video/                     # Database schemas
│   ├── video.ex
│   ├── video_frame.ex
│   ├── video_caption.ex
│   └── frame_caption.ex
└── srt_parser.ex              # SRT file parsing utilities

lib/nathan_for_us_web/live/
└── video_search_live.ex       # Search interface
```

This system enables searching any spoken content in Nathan Fielder interviews and retrieving the exact frames where those words were said. The automation scripts make it possible to go from a YouTube URL to a fully searchable production deployment with a single command.