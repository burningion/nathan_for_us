defmodule NathanForUs.Video.GifCacheTest do
  use NathanForUs.DataCase

  alias NathanForUs.Video.GifCache
  alias NathanForUs.Video

  describe "generate_cache_key/2" do
    test "generates consistent cache key for same inputs" do
      key1 = GifCache.generate_cache_key(1, [100, 101, 102])
      key2 = GifCache.generate_cache_key(1, [100, 101, 102])

      assert key1 == key2
    end

    test "generates different cache keys for different video_ids" do
      key1 = GifCache.generate_cache_key(1, [100, 101, 102])
      key2 = GifCache.generate_cache_key(2, [100, 101, 102])

      assert key1 != key2
    end

    test "generates different cache keys for different frame_ids" do
      key1 = GifCache.generate_cache_key(1, [100, 101, 102])
      key2 = GifCache.generate_cache_key(1, [100, 101, 103])

      assert key1 != key2
    end

    test "generates same cache key regardless of frame_ids order" do
      key1 = GifCache.generate_cache_key(1, [102, 100, 101])
      key2 = GifCache.generate_cache_key(1, [100, 101, 102])

      assert key1 == key2
    end
  end

  describe "lookup_cache/2" do
    test "returns nil when cache entry doesn't exist" do
      result = GifCache.lookup_cache(999, [1, 2, 3])
      assert is_nil(result)
    end
  end

  describe "store_cache/4" do
    test "stores GIF data in cache" do
      # Create a test video first
      {:ok, video} =
        Video.create_video(%{
          title: "Test Video",
          file_path: "/test/path.mp4",
          status: "completed"
        })

      frame_ids = [100, 101, 102]
      # Mock GIF data
      gif_data = <<137, 80, 78, 71>>

      {:ok, cached_gif} = GifCache.store_cache(video.id, frame_ids, gif_data)

      assert cached_gif.video_id == video.id
      assert cached_gif.frame_ids == frame_ids
      assert cached_gif.gif_data == gif_data
      assert cached_gif.file_size == byte_size(gif_data)
      assert cached_gif.access_count == 1
    end
  end
end
