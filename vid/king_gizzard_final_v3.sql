-- King Gizzard & The Lizard Wizard Concert Production Database Dump
-- YouTube Video: https://www.youtube.com/watch?v=LiQB-YLo-Eg
-- Let PostgreSQL handle all sequence generation

BEGIN;

-- Insert video metadata (let sequence handle ID)
INSERT INTO videos (title, file_path, duration_ms, fps, frame_count, status, processed_at, metadata, inserted_at, updated_at) 
VALUES (
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
) RETURNING id;

-- Store the video ID in a variable for the session
\gset video_id_

-- Insert captions using the video ID we just created
DO $$
DECLARE
    kg_video_id integer;
BEGIN
    -- Get the video ID we just inserted
    SELECT id INTO kg_video_id FROM videos 
    WHERE title = 'King Gizzard & The Lizard Wizard - Plovdiv, Bulgaria 06/10/25' 
    ORDER BY id DESC LIMIT 1;
    
    -- Insert captions
    INSERT INTO video_captions (video_id, start_time_ms, end_time_ms, text, caption_index, inserted_at, updated_at) VALUES
    (kg_video_id, 0, 10000, 'King Gizzard & The Lizard Wizard live in Plovdiv, Bulgaria', 1, NOW(), NOW()),
    (kg_video_id, 10000, 20000, 'Live concert performance', 2, NOW(), NOW()),
    (kg_video_id, 20000, 30000, 'Musical performance continues', 3, NOW(), NOW()),
    (kg_video_id, 30000, 40000, 'Band performing on stage', 4, NOW(), NOW()),
    (kg_video_id, 40000, 50000, 'Live music concert', 5, NOW(), NOW()),
    (kg_video_id, 50000, 60000, 'Concert in progress', 6, NOW(), NOW()),
    (kg_video_id, 60000, 70000, 'King Gizzard performing', 7, NOW(), NOW()),
    (kg_video_id, 70000, 80000, 'Live musical performance', 8, NOW(), NOW()),
    (kg_video_id, 80000, 90000, 'Band on stage in Bulgaria', 9, NOW(), NOW()),
    (kg_video_id, 90000, 100000, 'Concert continues', 10, NOW(), NOW()),
    (kg_video_id, 100000, 110000, 'Musical performance', 11, NOW(), NOW()),
    (kg_video_id, 110000, 120000, 'Live concert event', 12, NOW(), NOW()),
    (kg_video_id, 120000, 124000, 'End of recorded segment', 13, NOW(), NOW());
    
    -- Insert frames
    FOR i IN 0..123 LOOP
        INSERT INTO video_frames (video_id, frame_number, timestamp_ms, file_path, file_size, width, height, inserted_at, updated_at) 
        VALUES (
            kg_video_id, 
            i, 
            i * 1000, 
            format('priv/static/frames/video_%s/frame_%08d.jpg', kg_video_id, i + 1),
            83000 + (i % 20) * 100,
            1280, 
            720, 
            NOW(), 
            NOW()
        );
    END LOOP;
    
    -- Create frame-caption associations
    INSERT INTO frame_captions (frame_id, caption_id, inserted_at, updated_at)
    SELECT DISTINCT f.id, c.id, NOW(), NOW()
    FROM video_frames f
    JOIN video_captions c ON f.video_id = c.video_id
    WHERE f.timestamp_ms >= c.start_time_ms 
      AND f.timestamp_ms <= c.end_time_ms
      AND f.video_id = kg_video_id;
      
    -- Output the video ID for reference
    RAISE NOTICE 'King Gizzard video inserted with ID: %', kg_video_id;
END $$;

COMMIT;

-- Verification
SELECT 'SUCCESS: Video inserted' as status, id, title, frame_count FROM videos 
WHERE title = 'King Gizzard & The Lizard Wizard - Plovdiv, Bulgaria 06/10/25';

SELECT 'Frames count:' as status, COUNT(*) as total FROM video_frames f
JOIN videos v ON v.id = f.video_id
WHERE v.title = 'King Gizzard & The Lizard Wizard - Plovdiv, Bulgaria 06/10/25';

SELECT 'Captions count:' as status, COUNT(*) as total FROM video_captions c
JOIN videos v ON v.id = c.video_id  
WHERE v.title = 'King Gizzard & The Lizard Wizard - Plovdiv, Bulgaria 06/10/25';

SELECT 'Links count:' as status, COUNT(*) as total FROM frame_captions fc
JOIN video_frames f ON f.id = fc.frame_id
JOIN videos v ON v.id = f.video_id
WHERE v.title = 'King Gizzard & The Lizard Wizard - Plovdiv, Bulgaria 06/10/25';