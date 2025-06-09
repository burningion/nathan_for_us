# Nathan For Us - Comprehensive Memory

## System Overview

Nathan For Us is a Phoenix LiveView application that analyzes Nathan Fielder content through two main systems:

1. **Video Search System** - Frame-by-frame video analysis with caption search
2. **Skeets Coverage System** - Real-time Bluesky social media monitoring

The system enables users to search for any spoken dialogue in Nathan's interviews and see the exact frames where those words were said, plus monitor social media mentions in real-time.

## Quick Start Guide

### Getting the App Running

```bash
# Install dependencies and setup database
mix setup

# Start Phoenix server
mix phx.server

# Visit http://localhost:4000
```

**Key routes:**
- `/` - Home page
- `/video-search` - Video search interface
- `/skeets` - Bluesky mention monitoring (requires authentication)
- `/admin` - Admin panel (requires admin privileges)

### Basic Commands

```bash
# Run tests
mix test

# Database commands
mix ecto.create
mix ecto.migrate
mix ecto.drop

# Check app status
mix phx.routes
```

## Video Search System

### Current Implementation

The video search system provides **global search** across all videos simultaneously. Users can search for any spoken dialogue and see matching frames from all Nathan Fielder interviews.

**Live at:** https://www.nathanforus.com/video-search

#### Key Features

- **Cross-video search** - Single query searches all 5+ videos
- **Visual results** - Shows actual video frames with timestamps
- **Caption matching** - Finds exact dialogue with context
- **Video filtering** - Optional filtering to specific videos
- **Mosaic display** - Grid view of matching frames

#### Search Interface (`lib/nathan_for_us_web/live/video_search_live.ex`)

```elixir
# Global search across all videos
def handle_info({:perform_search, term}, socket) do
  results = case socket.assigns.search_mode do
    :global -> Video.search_frames_by_text_simple(term)
    :filtered -> Video.search_frames_by_text_simple_filtered(term, selected_video_ids)
  end
end
```

**UI Components:**
- Search header with status display
- Search form with quick suggestions ("nathan", "business", "train", "conan", "rehearsal")
- Video filter modal for selective searching
- Results grid showing frames with captions and video titles
- Loading states and empty states

#### Database Schema (`lib/nathan_for_us/video.ex`)

```sql
-- Videos metadata
CREATE TABLE videos (
  id SERIAL PRIMARY KEY,
  title VARCHAR NOT NULL,
  file_path VARCHAR NOT NULL UNIQUE,
  duration_ms INTEGER,
  frame_count INTEGER,
  status VARCHAR DEFAULT 'pending'
);

-- Individual video frames with binary image data
CREATE TABLE video_frames (
  id SERIAL PRIMARY KEY,
  video_id INTEGER REFERENCES videos(id),
  frame_number INTEGER NOT NULL,
  timestamp_ms INTEGER NOT NULL,
  image_data BYTEA, -- Compressed JPEG binary data
  file_size INTEGER,
  width INTEGER,
  height INTEGER
);

-- Subtitle/caption segments
CREATE TABLE video_captions (
  id SERIAL PRIMARY KEY,
  video_id INTEGER REFERENCES videos(id),
  start_time_ms INTEGER NOT NULL,
  end_time_ms INTEGER NOT NULL,
  text TEXT NOT NULL
);

-- Links frames to their captions by timestamp
CREATE TABLE frame_captions (
  frame_id INTEGER REFERENCES video_frames(id),
  caption_id INTEGER REFERENCES video_captions(id)
);
```

#### Search Functionality

```elixir
# Global search across all videos
def search_frames_by_text_simple(search_term) do
  query = """
  SELECT DISTINCT f.*, 
         v.title as video_title,
         string_agg(DISTINCT c.text, ' | ') as caption_texts
  FROM video_frames f
  JOIN videos v ON v.id = f.video_id
  JOIN frame_captions fc ON fc.frame_id = f.id
  JOIN video_captions c ON c.id = fc.caption_id
  WHERE c.text ILIKE $1
  GROUP BY f.id, ..., v.title
  ORDER BY v.title, f.timestamp_ms
  """
end

# Filtered search for specific videos
def search_frames_by_text_simple_filtered(search_term, video_ids) do
  # Same query with additional WHERE f.video_id = ANY($2)
end
```

### Video Processing Pipeline

#### Automated Processing (`scripts/complete_video_sync.exs`)

**Full YouTube to Production pipeline:**
```bash
# Download, process, and deploy to production
elixir scripts/complete_video_sync.exs "https://youtube.com/watch?v=..."

# With custom title
elixir scripts/complete_video_sync.exs "URL" "Custom Title"

# Sync existing videos to production
elixir scripts/complete_video_sync.exs sync_only [video_id]
```

#### Manual Processing Steps

1. **Download video:**
```bash
yt-dlp -f 'best[height<=720]' --write-sub --write-auto-sub --sub-lang en --convert-subs srt "YOUTUBE_URL"
```

2. **Process locally:**
```elixir
{:ok, video} = NathanForUs.VideoProcessing.process_video("/path/to/video.mp4")
```

3. **Verify processing:**
```elixir
video = NathanForUs.Video.get_video!(video_id)
results = NathanForUs.Video.search_frames_by_text_simple("train")
```

#### Processing Components (`lib/nathan_for_us/video_processing/`)

- **Producer** - GenStage queue management
- **FrameExtractor** - FFmpeg frame extraction at 1fps  
- **CaptionParser** - SRT file parsing to timestamped segments
- **DatabaseConsumer** - Batch storage in PostgreSQL

### Alternative Video-Specific Search

The original video-specific search implementation is preserved in `video_search_live_with_video_selector.ex` for future "episode search" functionality.

**To restore:**
```bash
cp lib/nathan_for_us_web/live/video_search_live_with_video_selector.ex lib/nathan_for_us_web/live/episode_search_live.ex
# Update module name and add route
```

## Skeets Coverage System

### Real-time Bluesky Monitoring

The skeets system monitors Bluesky (AT Protocol) for mentions of Nathan Fielder in real-time using the firehose stream.

**Live at:** https://www.nathanforus.com/skeets

#### Key Features

- **Real-time monitoring** via AT Protocol firehose
- **Live updates** using Phoenix PubSub and LiveView
- **Rich media display** - images, videos, external links
- **User profiles** - automatic fetching of Bluesky user data
- **Mention log** - terminal/captain's log aesthetic
- **Filtered content** - excludes test accounts

#### Skeets Interface (`lib/nathan_for_us_web/live/skeets_live.ex`)

```elixir
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(NathanForUs.PubSub, "nathan_fielder_skeets")
  end
  
  bluesky_posts = Social.list_bluesky_posts_with_users(limit: 50)
  {:ok, assign(socket, bluesky_posts: bluesky_posts)}
end

def handle_info({:new_nathan_fielder_skeet, post}, socket) do
  {:noreply, update(socket, :bluesky_posts, fn posts -> [post | posts] end)}
end
```

#### Database Schema (`lib/nathan_for_us/social.ex`)

```sql
-- Bluesky posts from firehose
CREATE TABLE bluesky_posts (
  id SERIAL PRIMARY KEY,
  cid VARCHAR NOT NULL UNIQUE,
  rkey VARCHAR,
  record_text TEXT,
  record_created_at TIMESTAMP,
  record_langs VARCHAR[],
  embed_type VARCHAR, -- "external", "images", "video"
  embed_uri TEXT,
  embed_title TEXT,
  embed_description TEXT,
  embed_thumb TEXT,
  bluesky_user_id INTEGER REFERENCES bluesky_users(id)
);

-- Bluesky user profiles
CREATE TABLE bluesky_users (
  id SERIAL PRIMARY KEY,
  did VARCHAR NOT NULL UNIQUE,
  handle VARCHAR,
  display_name VARCHAR,
  avatar_url TEXT,
  description TEXT
);
```

#### Firehose Integration (`lib/bluesky_hose.ex`)

```elixir
# Streams AT Protocol firehose for Nathan Fielder mentions
def handle_frame({:text, text}, state) do
  with {:ok, data} <- Jason.decode(text),
       true <- is_nathan_fielder_post?(data) do
    NathanForUs.Social.create_bluesky_post_from_record(data)
  end
end

defp is_nathan_fielder_post?(data) do
  # Checks for "nathan fielder" mentions in post text
end
```

#### UI Components

**Post Display:**
- Terminal/captain's log styling with monospace fonts
- Post metadata: timestamp, user info, language
- Rich media embeds: images, videos, external links  
- Source links to original Bluesky posts
- Real-time updates without page refresh

**Media Handling:**
- Image thumbnails with CDN URLs
- Video previews with play buttons
- External link previews with metadata
- Avatar display for post authors

### Social Context (`lib/nathan_for_us/social.ex`)

```elixir
# Create post from firehose data
def create_bluesky_post_from_record(record_data) do
  attrs = BlueskyPost.from_firehose_record(record_data)
  
  # Get or create user profile
  case get_or_create_bluesky_user_by_did(record_data["repo"]) do
    {:ok, user} -> Map.put(attrs, :bluesky_user_id, user.id)
    {:error, _} -> attrs
  end
end

# Fetch user from Bluesky API
def fetch_and_store_bluesky_user(did) do
  case BlueskyAPI.get_profile_by_did(did) do
    {:ok, profile_data} ->
      attrs = BlueskyUser.from_api_profile(profile_data)
      %BlueskyUser{} |> BlueskyUser.changeset(attrs) |> Repo.insert()
  end
end
```

## Configuration & Deployment

### Local Development

```elixir
# config/dev.exs
config :nathan_for_us, NathanForUs.Repo,
  username: "postgres",
  password: "postgres", 
  hostname: "localhost",
  database: "nathan_for_us_dev"
```

### Production (Gigalixir)

- **Database:** Managed PostgreSQL addon
- **Deployment:** Git push to main branch
- **Access:** `gigalixir pg:psql` for database operations

**Production utilities:**
```bash
# Database statistics
elixir scripts/video_utils.exs stats

# Test search functionality  
elixir scripts/video_utils.exs test_search 4 "train"

# System status
elixir scripts/video_utils.exs status
```

## Authentication & Authorization

### User System (`lib/nathan_for_us/accounts/`)

```elixir
# Standard Phoenix authentication with:
- User registration/login
- Email confirmation  
- Password reset
- Session management
- Admin role assignment
```

### Protected Routes

- `/skeets` - Requires authenticated user
- `/admin` - Requires admin user (`is_admin: true`)
- `/video-search` - Public access
- `/` - Public access

### Admin Features (`lib/nathan_for_us_web/live/admin_live.ex`)

- User management
- System statistics
- Video processing status
- Database health monitoring

## Testing

### Key Test Files

```bash
test/nathan_for_us/
├── accounts_test.exs          # User authentication
├── social_test.exs            # Bluesky integration  
├── video_processing_test.exs  # Video pipeline
└── srt_parser_test.exs        # Caption parsing

test/nathan_for_us_web/
├── controllers/               # HTTP endpoints
└── live/                      # LiveView functionality
```

### Running Tests

```bash
# All tests
mix test

# Specific context
mix test test/nathan_for_us/video_processing_test.exs

# LiveView tests
mix test test/nathan_for_us_web/live/
```

## Performance & Monitoring

### Database Performance

- **PostgreSQL GIN indexes** for full-text search on captions
- **ILIKE queries** for case-insensitive text matching
- **Batch operations** for frame/caption insertion
- **Binary storage** with JPEG compression (~75% reduction)

### Search Performance

- **Global search:** ~25ms across all videos
- **Filtered search:** ~15ms for specific videos  
- **Results:** Up to 123 matches for common terms
- **Memory:** Efficient with proper indexing

### Real-time Updates

- **Phoenix PubSub** for live updates
- **AT Protocol firehose** for real-time social monitoring
- **LiveView** for reactive UI updates
- **WebSocket** connections for low-latency updates

## Troubleshooting

### Common Issues

**No search results:**
```sql
-- Check video has frames
SELECT COUNT(*) FROM video_frames WHERE video_id = ?;

-- Check frame-caption links  
SELECT COUNT(*) FROM frame_captions fc 
JOIN video_frames f ON fc.frame_id = f.id 
WHERE f.video_id = ?;
```

**Image display issues:**
- Verify `image_data` contains JPEG binary data
- Check `encode_image_data/1` function for base64 encoding
- Ensure hex data properly decoded from `\\x` prefix

**Bluesky connection issues:**
- Check AT Protocol firehose connectivity
- Verify Bluesky API credentials
- Monitor PubSub subscription status

### Maintenance Commands

```bash
# Fix database sequences
elixir scripts/video_utils.exs fix_sequence

# Check frame-caption link integrity
elixir scripts/video_utils.exs check_links [video_id]

# System health check
elixir scripts/video_utils.exs status
```

## Architecture Highlights

### Phoenix LiveView Benefits

- **Real-time updates** without JavaScript complexity
- **Server-side rendering** with client-side interactivity  
- **State management** handled by Elixir processes
- **WebSocket connections** managed automatically

### Elixir/OTP Features

- **GenStage** for video processing pipeline
- **GenServer** for long-running processes
- **Supervision trees** for fault tolerance
- **Pattern matching** for data transformation

### PostgreSQL Integration

- **Full-text search** with GIN indexes
- **Binary data storage** for frame images
- **JSONB fields** for flexible metadata
- **Referential integrity** with foreign keys

## Current Status

### Production Deployment
✅ **5 videos processed** with full search capability  
✅ **4,302 frames** with binary image data  
✅ **2,842 captions** fully searchable  
✅ **Real-time Bluesky monitoring** active  
✅ **Global search interface** deployed  

### Feature Completeness
✅ **Video search** - Global and filtered search modes  
✅ **Skeets monitoring** - Real-time social media tracking  
✅ **User authentication** - Registration, login, admin roles  
✅ **Production deployment** - Automated scripts and utilities  
✅ **Performance optimization** - Efficient queries and storage  

The system successfully enables users to search any spoken content in Nathan Fielder interviews and monitor real-time social media mentions, providing comprehensive content analysis and monitoring capabilities.