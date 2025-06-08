# NOTE THIS IS ONLY TO BE CONSIDERED FOR INSPIRATION YOU ARE BUILDING THIS IN ELIXIR
Let me break down the numbers for processing a full season of "The Rehearsal" on a modern MacBook Pro:

## The Numbers

**Season 1 of The Rehearsal:**
- 6 episodes × ~45 minutes average = **270 minutes of footage**
- At 24 fps: **388,800 frames** total
- At 30 fps: **486,000 frames** total

## Storage Requirements

```python
# Quick calculation
frames = 388_800
avg_frame_size = 300  # KB (decent JPEG quality)
thumbnail_size = 30   # KB

storage_needed = (frames * (avg_frame_size + thumbnail_size)) / 1024 / 1024
print(f"Total storage: {storage_needed:.1f} GB")
# Result: ~125 GB
```

## Processing Time Estimates

On a modern MacBook Pro (M1/M2/M3), here's what to expect:

```python
# Realistic processing timeline
extraction_fps = 60      # frames/second extraction rate
s3_upload_fps = 20      # frames/second (depends on internet)
db_insert_fps = 1000    # frames/second (batched)

total_time_hours = frames / min(extraction_fps, s3_upload_fps) / 3600
print(f"Processing time: {total_time_hours:.1f} hours")
# Result: ~5.4 hours
```

## Bottlenecks & Solutions

### 1. **Video Decoding** ✅ Not Bad
- Modern MacBooks have hardware video decoders
- Can easily do 60-120 fps extraction
- Use `VideoToolbox` acceleration in ffmpeg

### 2. **S3 Uploads** ⚠️ Main Bottleneck
```python
# Parallel upload strategy
from concurrent.futures import ThreadPoolExecutor
import asyncio

class OptimizedUploader:
    def __init__(self, workers=10):
        self.executor = ThreadPoolExecutor(max_workers=workers)
        self.upload_queue = asyncio.Queue()
    
    async def process_episode(self, video_path):
        # Extract frames in one thread
        extraction_task = asyncio.create_task(
            self.extract_frames(video_path)
        )
        
        # Upload in parallel with multiple workers
        upload_tasks = [
            asyncio.create_task(self.upload_worker())
            for _ in range(10)
        ]
        
        await extraction_task
        await self.upload_queue.join()
```

### 3. **Local Processing** ✅ Very Doable
```bash
# Optimize with local processing first
1. Extract all frames locally first (1-2 hours)
2. Process captions and build indexes
3. Upload to S3 in background overnight
4. Keep working with local data immediately
```

## Optimized Approach for MacBook

```python
# macbook_pipeline.py
class MacBookOptimizedPipeline:
    def __init__(self):
        self.local_cache = Path("~/.nathan-cache").expanduser()
        self.batch_size = 1000
        
    def process_season_smart(self, season_videos: list):
        """Process efficiently on MacBook"""
        
        # Phase 1: Local extraction (fast)
        print("Phase 1: Extracting frames locally...")
        for video in season_videos:
            self.extract_frames_locally(video)
            # This runs at ~100+ fps on M1/M2
        
        # Phase 2: Database population (immediate)
        print("Phase 2: Building searchable index...")
        self.populate_postgres()  # Works with local paths
        
        # Phase 3: Background S3 sync (can work overnight)
        print("Phase 3: Syncing to S3 (can run in background)...")
        self.background_s3_sync()  # Fire and forget
        
    def extract_frames_locally(self, video_path):
        """Use hardware acceleration"""
        cmd = [
            'ffmpeg',
            '-hwaccel', 'videotoolbox',  # Mac hardware acceleration
            '-i', video_path,
            '-vf', 'fps=1',  # 1 fps for analysis (24x reduction!)
            '-q:v', '2',     # High quality
            f'{self.local_cache}/frames/%08d.jpg'
        ]
        subprocess.run(cmd)
```

## Smart Optimizations

### 1. **Reduce Frame Rate**
```python
# Instead of every frame, sample intelligently
def smart_sampling(video_path):
    """Extract frames only when scene changes"""
    
    # Option 1: Fixed sampling (1 fps = 24x reduction)
    # 388,800 frames → 16,200 frames
    
    # Option 2: Scene detection
    cmd = [
        'ffmpeg', '-i', video_path,
        '-vf', 'select=gt(scene\\,0.4)',  # Scene changes only
        '-vsync', 'vfr',
        'frames/%08d.jpg'
    ]
```

### 2. **Progressive Processing**
```python
# Start with thumbnails, upgrade later
def progressive_pipeline():
    # Day 1: Low-res thumbnails + full text search
    extract_thumbnails()  # 30 min
    
    # Day 2: Full frames for interesting scenes
    extract_full_frames_for_matches()  # As needed
```

### 3. **Local-First Architecture**
```sql
-- Use SQLite for initial development
-- It's FAST on local SSD
CREATE TABLE frames (
    id INTEGER PRIMARY KEY,
    timestamp_ms INTEGER,
    local_path TEXT,
    s3_key TEXT,  -- NULL until uploaded
    uploaded_at TIMESTAMP
);
```

## Realistic Timeline

**For full frame-by-frame processing:**
- **Extraction**: 1-2 hours
- **Local DB population**: 30 minutes  
- **S3 upload**: 4-6 hours (run overnight)
- **Total active time**: ~2.5 hours

**For smart sampling (recommended):**
- **1 fps extraction**: 10 minutes
- **Scene detection**: 20 minutes
- **Ready to search**: 30 minutes total

## The Verdict

It's **totally doable** on a modern MacBook Pro! The key is:

1. Start with smart sampling (1 fps or scene detection)
2. Use local storage first, S3 later
3. Let uploads run in background/overnight
4. Use hardware acceleration for video processing

You could have a searchable prototype running in under an hour, then let the full processing happen while you sleep. The M-series chips are beasts for this kind of work.

Want me to write the optimized extraction script that'll run well on your MacBook?
