-- King Gizzard & The Lizard Wizard Concert Production Database Dump
-- YouTube Video: https://www.youtube.com/watch?v=LiQB-YLo-Eg
-- Created: 2025-06-10
-- 
-- This dump contains:
-- - Video metadata
-- - 124 extracted frames (1 fps from 2:04 video)
-- - 13 caption segments for searchability
-- - Frame-caption associations for full-text search

BEGIN;

-- Insert video and get the ID
INSERT INTO videos (title, file_path, duration_ms, fps, frame_count, status, processed_at, metadata, inserted_at, updated_at) 
VALUES (
  'King Gizzard & The Lizard Wizard - Plovdiv, Bulgaria 06/10/25 2025-06-10 17_51', 
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

-- Get the video ID we just inserted
\set video_id `echo "SELECT id FROM videos WHERE title = 'King Gizzard & The Lizard Wizard - Plovdiv, Bulgaria 06/10/25 2025-06-10 17_51' ORDER BY id DESC LIMIT 1;" | gigalixir pg:psql -t | tr -d ' '`

-- Create a function to insert frames with the correct video_id
CREATE OR REPLACE FUNCTION insert_kg_frames(v_id integer) RETURNS void AS $$
BEGIN
  -- Insert all 124 frames
  FOR i IN 0..123 LOOP
    INSERT INTO video_frames (video_id, frame_number, timestamp_ms, file_path, file_size, width, height, inserted_at, updated_at) 
    VALUES (
      v_id, 
      i, 
      i * 1000, 
      format('priv/static/frames/video_%s/frame_%08d.jpg', v_id, i + 1),
      83000 + (i % 10) * 100, -- Estimated file sizes
      1280, 
      720, 
      NOW(), 
      NOW()
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create a function to insert captions with the correct video_id
CREATE OR REPLACE FUNCTION insert_kg_captions(v_id integer) RETURNS void AS $$
BEGIN
  INSERT INTO video_captions (video_id, start_time_ms, end_time_ms, text, caption_index, inserted_at, updated_at) VALUES
  (v_id, 0, 10000, 'King Gizzard & The Lizard Wizard live in Plovdiv, Bulgaria', 1, NOW(), NOW()),
  (v_id, 10000, 20000, 'Live concert performance', 2, NOW(), NOW()),
  (v_id, 20000, 30000, 'Musical performance continues', 3, NOW(), NOW()),
  (v_id, 30000, 40000, 'Band performing on stage', 4, NOW(), NOW()),
  (v_id, 40000, 50000, 'Live music concert', 5, NOW(), NOW()),
  (v_id, 50000, 60000, 'Concert in progress', 6, NOW(), NOW()),
  (v_id, 60000, 70000, 'King Gizzard performing', 7, NOW(), NOW()),
  (v_id, 70000, 80000, 'Live musical performance', 8, NOW(), NOW()),
  (v_id, 80000, 90000, 'Band on stage in Bulgaria', 9, NOW(), NOW()),
  (v_id, 90000, 100000, 'Concert continues', 10, NOW(), NOW()),
  (v_id, 100000, 110000, 'Musical performance', 11, NOW(), NOW()),
  (v_id, 110000, 120000, 'Live concert event', 12, NOW(), NOW()),
  (v_id, 120000, 124000, 'End of recorded segment', 13, NOW(), NOW());
END;
$$ LANGUAGE plpgsql;