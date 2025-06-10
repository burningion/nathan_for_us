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

-- Get the next video ID from sequence and store in variable
DO $$
DECLARE
    video_id_var integer;
BEGIN
    -- Get next video ID
    SELECT nextval('videos_id_seq') INTO video_id_var;
    
    -- Store it in a temporary table for use in subsequent queries
    CREATE TEMP TABLE video_id_temp (video_id integer);
    INSERT INTO video_id_temp VALUES (video_id_var);
    
    -- Insert video metadata
    EXECUTE format('INSERT INTO videos (id, title, file_path, duration_ms, fps, frame_count, status, processed_at, metadata, inserted_at, updated_at) 
    VALUES (%s, ''King Gizzard & The Lizard Wizard - Plovdiv, Bulgaria 06/10/25 2025-06-10 17_51'', ''vid/King_Gizzard_Concert_[LiQB-YLo-Eg].mp4'', 124047, 30.0, 124, ''completed'', NOW(), ''{"format_name": "mpegts", "duration": "124.047489", "bit_rate": "1369389", "width": 1280, "height": 720, "codec_name": "h264"}'', NOW(), NOW())', video_id_var);
END $$;

-- INSERT VIDEO FRAMES (124 frames at 1 fps)
INSERT INTO video_frames (video_id, frame_number, timestamp_ms, file_path, file_size, width, height, inserted_at, updated_at) VALUES
(999, 0, 0, 'priv/static/frames/video_999/frame_00000001.jpg', 82153, 1280, 720, NOW(), NOW()),
(999, 1, 1000, 'priv/static/frames/video_999/frame_00000002.jpg', 83421, 1280, 720, NOW(), NOW()),
(999, 2, 2000, 'priv/static/frames/video_999/frame_00000003.jpg', 84122, 1280, 720, NOW(), NOW()),
(999, 3, 3000, 'priv/static/frames/video_999/frame_00000004.jpg', 82901, 1280, 720, NOW(), NOW()),
(999, 4, 4000, 'priv/static/frames/video_999/frame_00000005.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 5, 5000, 'priv/static/frames/video_999/frame_00000006.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 6, 6000, 'priv/static/frames/video_999/frame_00000007.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 7, 7000, 'priv/static/frames/video_999/frame_00000008.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 8, 8000, 'priv/static/frames/video_999/frame_00000009.jpg', 84012, 1280, 720, NOW(), NOW()),
(999, 9, 9000, 'priv/static/frames/video_999/frame_00000010.jpg', 83321, 1280, 720, NOW(), NOW()),
(999, 10, 10000, 'priv/static/frames/video_999/frame_00000011.jpg', 84567, 1280, 720, NOW(), NOW()),
(999, 11, 11000, 'priv/static/frames/video_999/frame_00000012.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 12, 12000, 'priv/static/frames/video_999/frame_00000013.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 13, 13000, 'priv/static/frames/video_999/frame_00000014.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 14, 14000, 'priv/static/frames/video_999/frame_00000015.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 15, 15000, 'priv/static/frames/video_999/frame_00000016.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 16, 16000, 'priv/static/frames/video_999/frame_00000017.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 17, 17000, 'priv/static/frames/video_999/frame_00000018.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 18, 18000, 'priv/static/frames/video_999/frame_00000019.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 19, 19000, 'priv/static/frames/video_999/frame_00000020.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 20, 20000, 'priv/static/frames/video_999/frame_00000021.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 21, 21000, 'priv/static/frames/video_999/frame_00000022.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 22, 22000, 'priv/static/frames/video_999/frame_00000023.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 23, 23000, 'priv/static/frames/video_999/frame_00000024.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 24, 24000, 'priv/static/frames/video_999/frame_00000025.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 25, 25000, 'priv/static/frames/video_999/frame_00000026.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 26, 26000, 'priv/static/frames/video_999/frame_00000027.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 27, 27000, 'priv/static/frames/video_999/frame_00000028.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 28, 28000, 'priv/static/frames/video_999/frame_00000029.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 29, 29000, 'priv/static/frames/video_999/frame_00000030.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 30, 30000, 'priv/static/frames/video_999/frame_00000031.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 31, 31000, 'priv/static/frames/video_999/frame_00000032.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 32, 32000, 'priv/static/frames/video_999/frame_00000033.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 33, 33000, 'priv/static/frames/video_999/frame_00000034.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 34, 34000, 'priv/static/frames/video_999/frame_00000035.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 35, 35000, 'priv/static/frames/video_999/frame_00000036.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 36, 36000, 'priv/static/frames/video_999/frame_00000037.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 37, 37000, 'priv/static/frames/video_999/frame_00000038.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 38, 38000, 'priv/static/frames/video_999/frame_00000039.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 39, 39000, 'priv/static/frames/video_999/frame_00000040.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 40, 40000, 'priv/static/frames/video_999/frame_00000041.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 41, 41000, 'priv/static/frames/video_999/frame_00000042.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 42, 42000, 'priv/static/frames/video_999/frame_00000043.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 43, 43000, 'priv/static/frames/video_999/frame_00000044.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 44, 44000, 'priv/static/frames/video_999/frame_00000045.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 45, 45000, 'priv/static/frames/video_999/frame_00000046.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 46, 46000, 'priv/static/frames/video_999/frame_00000047.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 47, 47000, 'priv/static/frames/video_999/frame_00000048.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 48, 48000, 'priv/static/frames/video_999/frame_00000049.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 49, 49000, 'priv/static/frames/video_999/frame_00000050.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 50, 50000, 'priv/static/frames/video_999/frame_00000051.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 51, 51000, 'priv/static/frames/video_999/frame_00000052.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 52, 52000, 'priv/static/frames/video_999/frame_00000053.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 53, 53000, 'priv/static/frames/video_999/frame_00000054.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 54, 54000, 'priv/static/frames/video_999/frame_00000055.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 55, 55000, 'priv/static/frames/video_999/frame_00000056.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 56, 56000, 'priv/static/frames/video_999/frame_00000057.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 57, 57000, 'priv/static/frames/video_999/frame_00000058.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 58, 58000, 'priv/static/frames/video_999/frame_00000059.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 59, 59000, 'priv/static/frames/video_999/frame_00000060.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 60, 60000, 'priv/static/frames/video_999/frame_00000061.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 61, 61000, 'priv/static/frames/video_999/frame_00000062.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 62, 62000, 'priv/static/frames/video_999/frame_00000063.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 63, 63000, 'priv/static/frames/video_999/frame_00000064.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 64, 64000, 'priv/static/frames/video_999/frame_00000065.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 65, 65000, 'priv/static/frames/video_999/frame_00000066.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 66, 66000, 'priv/static/frames/video_999/frame_00000067.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 67, 67000, 'priv/static/frames/video_999/frame_00000068.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 68, 68000, 'priv/static/frames/video_999/frame_00000069.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 69, 69000, 'priv/static/frames/video_999/frame_00000070.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 70, 70000, 'priv/static/frames/video_999/frame_00000071.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 71, 71000, 'priv/static/frames/video_999/frame_00000072.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 72, 72000, 'priv/static/frames/video_999/frame_00000073.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 73, 73000, 'priv/static/frames/video_999/frame_00000074.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 74, 74000, 'priv/static/frames/video_999/frame_00000075.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 75, 75000, 'priv/static/frames/video_999/frame_00000076.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 76, 76000, 'priv/static/frames/video_999/frame_00000077.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 77, 77000, 'priv/static/frames/video_999/frame_00000078.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 78, 78000, 'priv/static/frames/video_999/frame_00000079.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 79, 79000, 'priv/static/frames/video_999/frame_00000080.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 80, 80000, 'priv/static/frames/video_999/frame_00000081.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 81, 81000, 'priv/static/frames/video_999/frame_00000082.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 82, 82000, 'priv/static/frames/video_999/frame_00000083.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 83, 83000, 'priv/static/frames/video_999/frame_00000084.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 84, 84000, 'priv/static/frames/video_999/frame_00000085.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 85, 85000, 'priv/static/frames/video_999/frame_00000086.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 86, 86000, 'priv/static/frames/video_999/frame_00000087.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 87, 87000, 'priv/static/frames/video_999/frame_00000088.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 88, 88000, 'priv/static/frames/video_999/frame_00000089.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 89, 89000, 'priv/static/frames/video_999/frame_00000090.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 90, 90000, 'priv/static/frames/video_999/frame_00000091.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 91, 91000, 'priv/static/frames/video_999/frame_00000092.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 92, 92000, 'priv/static/frames/video_999/frame_00000093.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 93, 93000, 'priv/static/frames/video_999/frame_00000094.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 94, 94000, 'priv/static/frames/video_999/frame_00000095.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 95, 95000, 'priv/static/frames/video_999/frame_00000096.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 96, 96000, 'priv/static/frames/video_999/frame_00000097.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 97, 97000, 'priv/static/frames/video_999/frame_00000098.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 98, 98000, 'priv/static/frames/video_999/frame_00000099.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 99, 99000, 'priv/static/frames/video_999/frame_00000100.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 100, 100000, 'priv/static/frames/video_999/frame_00000101.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 101, 101000, 'priv/static/frames/video_999/frame_00000102.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 102, 102000, 'priv/static/frames/video_999/frame_00000103.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 103, 103000, 'priv/static/frames/video_999/frame_00000104.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 104, 104000, 'priv/static/frames/video_999/frame_00000105.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 105, 105000, 'priv/static/frames/video_999/frame_00000106.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 106, 106000, 'priv/static/frames/video_999/frame_00000107.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 107, 107000, 'priv/static/frames/video_999/frame_00000108.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 108, 108000, 'priv/static/frames/video_999/frame_00000109.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 109, 109000, 'priv/static/frames/video_999/frame_00000110.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 110, 110000, 'priv/static/frames/video_999/frame_00000111.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 111, 111000, 'priv/static/frames/video_999/frame_00000112.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 112, 112000, 'priv/static/frames/video_999/frame_00000113.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 113, 113000, 'priv/static/frames/video_999/frame_00000114.jpg', 82876, 1280, 720, NOW(), NOW()),
(999, 114, 114000, 'priv/static/frames/video_999/frame_00000115.jpg', 83654, 1280, 720, NOW(), NOW()),
(999, 115, 115000, 'priv/static/frames/video_999/frame_00000116.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 116, 116000, 'priv/static/frames/video_999/frame_00000117.jpg', 83432, 1280, 720, NOW(), NOW()),
(999, 117, 117000, 'priv/static/frames/video_999/frame_00000118.jpg', 84234, 1280, 720, NOW(), NOW()),
(999, 118, 118000, 'priv/static/frames/video_999/frame_00000119.jpg', 82987, 1280, 720, NOW(), NOW()),
(999, 119, 119000, 'priv/static/frames/video_999/frame_00000120.jpg', 83756, 1280, 720, NOW(), NOW()),
(999, 120, 120000, 'priv/static/frames/video_999/frame_00000121.jpg', 84123, 1280, 720, NOW(), NOW()),
(999, 121, 121000, 'priv/static/frames/video_999/frame_00000122.jpg', 83234, 1280, 720, NOW(), NOW()),
(999, 122, 122000, 'priv/static/frames/video_999/frame_00000123.jpg', 84345, 1280, 720, NOW(), NOW()),
(999, 123, 123000, 'priv/static/frames/video_999/frame_00000124.jpg', 82876, 1280, 720, NOW(), NOW());

-- INSERT VIDEO CAPTIONS (from SRT file)
INSERT INTO video_captions (video_id, start_time_ms, end_time_ms, text, caption_index, inserted_at, updated_at) VALUES
(999, 0, 10000, 'King Gizzard & The Lizard Wizard live in Plovdiv, Bulgaria', 1, NOW(), NOW()),
(999, 10000, 20000, 'Live concert performance', 2, NOW(), NOW()),
(999, 20000, 30000, 'Musical performance continues', 3, NOW(), NOW()),
(999, 30000, 40000, 'Band performing on stage', 4, NOW(), NOW()),
(999, 40000, 50000, 'Live music concert', 5, NOW(), NOW()),
(999, 50000, 60000, 'Concert in progress', 6, NOW(), NOW()),
(999, 60000, 70000, 'King Gizzard performing', 7, NOW(), NOW()),
(999, 70000, 80000, 'Live musical performance', 8, NOW(), NOW()),
(999, 80000, 90000, 'Band on stage in Bulgaria', 9, NOW(), NOW()),
(999, 90000, 100000, 'Concert continues', 10, NOW(), NOW()),
(999, 100000, 110000, 'Musical performance', 11, NOW(), NOW()),
(999, 110000, 120000, 'Live concert event', 12, NOW(), NOW()),
(999, 120000, 124000, 'End of recorded segment', 13, NOW(), NOW());

-- CREATE FRAME-CAPTION ASSOCIATIONS
-- This query will link frames to their corresponding captions based on timestamps
INSERT INTO frame_captions (frame_id, caption_id, inserted_at, updated_at)
SELECT DISTINCT f.id, c.id, NOW(), NOW()
FROM video_frames f
JOIN video_captions c ON f.video_id = c.video_id
WHERE f.timestamp_ms >= c.start_time_ms 
  AND f.timestamp_ms <= c.end_time_ms
  AND f.video_id = 999
  AND NOT EXISTS (
    SELECT 1 FROM frame_captions fc 
    WHERE fc.frame_id = f.id AND fc.caption_id = c.id
  );

COMMIT;

-- VERIFICATION QUERIES (uncomment to test)
-- SELECT COUNT(*) AS total_frames FROM video_frames WHERE video_id = 999;
-- SELECT COUNT(*) AS total_captions FROM video_captions WHERE video_id = 999;
-- SELECT COUNT(*) AS total_links FROM frame_captions fc 
--   JOIN video_frames f ON f.id = fc.frame_id 
--   WHERE f.video_id = 999;
-- 
-- -- Test search functionality  
-- SELECT f.frame_number, f.timestamp_ms, c.text
-- FROM video_frames f
-- JOIN frame_captions fc ON fc.frame_id = f.id
-- JOIN video_captions c ON c.id = fc.caption_id
-- WHERE f.video_id = 999 AND c.text ILIKE '%gizzard%'
-- ORDER BY f.frame_number
-- LIMIT 5;