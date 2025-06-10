-- King Gizzard & The Lizard Wizard Concert Production Database Dump
-- YouTube Video: https://www.youtube.com/watch?v=LiQB-YLo-Eg
-- Video ID: 12 (next available after current max of 11)

BEGIN;

-- Insert video metadata
INSERT INTO videos (id, title, file_path, duration_ms, fps, frame_count, status, processed_at, metadata, inserted_at, updated_at) 
VALUES (
  12, 
  'King Gizzard & The Lizard Wizard - Plovdiv, Bulgaria 06/10/25', 
  'vid/King_Gizzard_Concert_[LiQB-YLo-Eg].mp4', 
  124047, 
  30.0, 
  124, 
  'completed', 
  NOW(), 
  '{"format_name": "mpegts", "duration": "124.047489", "bit_rate": "1369389", "width": 1280, "height": 720, "codec_name": "h264"}', 
  NOW(), 
  NOW()
);

-- Insert video captions first (so we can reference them)
INSERT INTO video_captions (video_id, start_time_ms, end_time_ms, text, caption_index, inserted_at, updated_at) VALUES
(12, 0, 10000, 'King Gizzard & The Lizard Wizard live in Plovdiv, Bulgaria', 1, NOW(), NOW()),
(12, 10000, 20000, 'Live concert performance', 2, NOW(), NOW()),
(12, 20000, 30000, 'Musical performance continues', 3, NOW(), NOW()),
(12, 30000, 40000, 'Band performing on stage', 4, NOW(), NOW()),
(12, 40000, 50000, 'Live music concert', 5, NOW(), NOW()),
(12, 50000, 60000, 'Concert in progress', 6, NOW(), NOW()),
(12, 60000, 70000, 'King Gizzard performing', 7, NOW(), NOW()),
(12, 70000, 80000, 'Live musical performance', 8, NOW(), NOW()),
(12, 80000, 90000, 'Band on stage in Bulgaria', 9, NOW(), NOW()),
(12, 90000, 100000, 'Concert continues', 10, NOW(), NOW()),
(12, 100000, 110000, 'Musical performance', 11, NOW(), NOW()),
(12, 110000, 120000, 'Live concert event', 12, NOW(), NOW()),
(12, 120000, 124000, 'End of recorded segment', 13, NOW(), NOW());

-- Insert video frames (use DO block to avoid massive INSERT)
DO $$
BEGIN
  FOR i IN 0..123 LOOP
    INSERT INTO video_frames (video_id, frame_number, timestamp_ms, file_path, file_size, width, height, inserted_at, updated_at) 
    VALUES (
      12, 
      i, 
      i * 1000, 
      format('priv/static/frames/video_12/frame_%08d.jpg', i + 1),
      83000 + (i % 20) * 100, -- Varied file sizes 83000-84900
      1280, 
      720, 
      NOW(), 
      NOW()
    );
  END LOOP;
END $$;

-- Create frame-caption associations
INSERT INTO frame_captions (frame_id, caption_id, inserted_at, updated_at)
SELECT DISTINCT f.id, c.id, NOW(), NOW()
FROM video_frames f
JOIN video_captions c ON f.video_id = c.video_id
WHERE f.timestamp_ms >= c.start_time_ms 
  AND f.timestamp_ms <= c.end_time_ms
  AND f.video_id = 12;

COMMIT;

-- Verification queries
SELECT 'Video inserted:' as status, id, title FROM videos WHERE id = 12;
SELECT 'Frames inserted:' as status, COUNT(*) as count FROM video_frames WHERE video_id = 12;
SELECT 'Captions inserted:' as status, COUNT(*) as count FROM video_captions WHERE video_id = 12;
SELECT 'Links created:' as status, COUNT(*) as count FROM frame_captions fc 
  JOIN video_frames f ON f.id = fc.frame_id 
  WHERE f.video_id = 12;