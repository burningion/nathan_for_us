defmodule NathanForUs.FrameCache do
  @moduledoc """
  ETS-based cache for video frame binary data.
  
  Caches frequently accessed video frames to reduce database load.
  Particularly useful for frames that are commonly used in GIF generation.
  
  Cache key structure: frame_id
  Cache value structure: {image_data, access_count, last_accessed, frame_metadata}
  """
  
  use GenServer
  require Logger
  
  @table_name :frame_cache
  @max_cache_size 200   # Conservative limit for 4GB RAM system  
  @max_memory_mb 256    # Conservative memory target - ~6% of total RAM
  @cleanup_interval 600_000  # 10 minutes
  @popularity_threshold 3     # Access count to be considered "popular"
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get frame image data from cache. Returns binary data or nil if not cached.
  """
  def get(frame_id) when is_integer(frame_id) do
    case :ets.lookup(@table_name, frame_id) do
      [{^frame_id, {image_data, access_count, _last_accessed, _metadata}}] ->
        # Update access count and timestamp asynchronously
        GenServer.cast(__MODULE__, {:record_access, frame_id, access_count + 1})
        image_data
        
      [] -> 
        nil
    end
  end
  
  @doc """
  Store frame image data in cache.
  """
  def put(frame_id, image_data, metadata \\ %{}) when is_integer(frame_id) and is_binary(image_data) do
    GenServer.cast(__MODULE__, {:put, frame_id, image_data, metadata})
  end
  
  @doc """
  Cache multiple frames at once (more efficient for bulk operations).
  """
  def put_batch(frames) when is_list(frames) do
    GenServer.cast(__MODULE__, {:put_batch, frames})
  end
  
  @doc """
  Record that a frame was used in GIF generation (increases priority).
  """
  def record_gif_usage(frame_id) when is_integer(frame_id) do
    case :ets.lookup(@table_name, frame_id) do
      [{^frame_id, {image_data, access_count, _last_accessed, metadata}}] ->
        # Mark as GIF frame and boost access count significantly
        enhanced_metadata = Map.put(metadata, :gif_usage_count, Map.get(metadata, :gif_usage_count, 0) + 1)
        updated_entry = {image_data, access_count + 5, DateTime.utc_now(), enhanced_metadata}
        :ets.insert(@table_name, {frame_id, updated_entry})
      [] ->
        # Frame not in cache, we'll catch it next time it's loaded
        :ok
    end
  end
  
  @doc """
  Warm cache with commonly accessed frames.
  """
  def warm_cache() do
    GenServer.cast(__MODULE__, :warm_cache)
  end
  
  @doc """
  Get cache statistics for monitoring.
  """
  def stats() do
    GenServer.call(__MODULE__, :stats)
  end
  
  @doc """
  Clear entire cache.
  """
  def clear() do
    GenServer.call(__MODULE__, :clear)
  end
  
  @doc """
  Remove specific frame from cache.
  """
  def evict(frame_id) when is_integer(frame_id) do
    GenServer.cast(__MODULE__, {:evict, frame_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    # Create ETS table for cache storage
    table = :ets.new(@table_name, [
      :set,           # Each frame_id can only have one entry
      :public,        # Allow direct reads from other processes
      :named_table,   # Use atom name instead of table reference
      {:read_concurrency, true},   # Optimize for concurrent reads
      {:write_concurrency, false}  # Optimize for single writer
    ])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    Logger.info("Frame cache started with table #{inspect(table)}")
    
    {:ok, %{table: table, memory_usage: 0}}
  end
  
  @impl true
  def handle_cast({:put, frame_id, image_data, metadata}, state) do
    image_size = byte_size(image_data)
    
    # Check if we need to evict before adding
    current_size = :ets.info(@table_name, :size)
    if current_size >= @max_cache_size do
      evict_multiple_lru_smart(1)
    end
    
    # Store in cache with metadata
    cache_entry = {image_data, 1, DateTime.utc_now(), metadata}
    :ets.insert(@table_name, {frame_id, cache_entry})
    
    new_memory_usage = state.memory_usage + image_size
    
    Logger.debug("Cached frame #{frame_id} (#{image_size} bytes)")
    
    {:noreply, %{state | memory_usage: new_memory_usage}}
  end
  
  @impl true
  def handle_cast({:put_batch, frames}, state) do
    total_size = 
      Enum.reduce(frames, 0, fn {frame_id, image_data, metadata}, acc ->
        image_size = byte_size(image_data)
        
        cache_entry = {image_data, 1, DateTime.utc_now(), metadata || %{}}
        :ets.insert(@table_name, {frame_id, cache_entry})
        
        acc + image_size
      end)
    
    # Perform cleanup if needed after batch insert
    current_size = :ets.info(@table_name, :size)
    if current_size > @max_cache_size do
      evict_count = current_size - @max_cache_size
      evict_multiple_lru_smart(evict_count)
    end
    
    new_memory_usage = state.memory_usage + total_size
    
    Logger.debug("Batch cached #{length(frames)} frames (#{total_size} bytes)")
    
    {:noreply, %{state | memory_usage: new_memory_usage}}
  end
  
  @impl true
  def handle_cast({:record_access, frame_id, new_access_count}, state) do
    case :ets.lookup(@table_name, frame_id) do
      [{^frame_id, {image_data, _old_count, _old_time, metadata}}] ->
        updated_entry = {image_data, new_access_count, DateTime.utc_now(), metadata}
        :ets.insert(@table_name, {frame_id, updated_entry})
      [] ->
        # Frame was evicted between lookup and access update
        :ok
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:evict, frame_id}, state) do
    case :ets.lookup(@table_name, frame_id) do
      [{^frame_id, {image_data, _access_count, _last_accessed, _metadata}}] ->
        :ets.delete(@table_name, frame_id)
        freed_memory = byte_size(image_data)
        new_memory_usage = max(0, state.memory_usage - freed_memory)
        Logger.debug("Evicted frame #{frame_id} from cache")
        {:noreply, %{state | memory_usage: new_memory_usage}}
      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:evict_multiple, count}, state) do
    evict_multiple_lru_smart(count)
    {:noreply, state}
  end
  
  @impl true
  def handle_cast(:warm_cache, state) do
    Task.start(fn -> 
      try do
        # Get frames from recent GIFs to identify commonly used frames
        recent_gifs = NathanForUs.Viral.get_recent_gifs(10)
        
        # Extract frame IDs from these GIFs
        frame_ids = 
          recent_gifs
          |> Enum.filter(& &1.gif && &1.gif.frame_ids)
          |> Enum.flat_map(& &1.gif.frame_ids)
          |> Enum.uniq()
          |> Enum.take(100)  # Limit to prevent overwhelming on startup
        
        # Load and cache frames in batches
        frame_ids
        |> Enum.chunk_every(20)
        |> Enum.each(fn batch_ids ->
          frames_with_data = NathanForUs.Video.get_frames_by_ids(batch_ids)
          
          batch_data = 
            frames_with_data
            |> Enum.filter(fn frame -> frame.image_data != nil end)
            |> Enum.map(fn frame -> 
              metadata = %{
                frame_number: frame.frame_number,
                video_id: frame.video_id,
                timestamp_ms: frame.timestamp_ms
              }
              {frame.id, frame.image_data, metadata}
            end)
          
          if length(batch_data) > 0 do
            put_batch(batch_data)
          end
        end)
        
        Logger.info("Frame cache warmed with frames from #{length(frame_ids)} recent GIF frames")
      rescue
        error ->
          Logger.error("Frame cache warming failed: #{inspect(error)}")
      end
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    cache_size = :ets.info(@table_name, :size)
    
    # Calculate actual memory usage and access patterns
    {total_memory, popular_count, gif_usage_count, total_accesses} = 
      :ets.foldl(fn {_frame_id, {image_data, access_count, _last_accessed, metadata}}, {mem_acc, pop_acc, gif_acc, access_acc} ->
        memory = mem_acc + byte_size(image_data)
        popular = if access_count >= @popularity_threshold, do: pop_acc + 1, else: pop_acc
        gif_usage = gif_acc + Map.get(metadata, :gif_usage_count, 0)
        {memory, popular, gif_usage, access_acc + access_count}
      end, {0, 0, 0, 0}, @table_name)
    
    avg_accesses = if cache_size > 0, do: Float.round(total_accesses / cache_size, 1), else: 0
    
    stats = %{
      cached_frames: cache_size,
      memory_usage_bytes: total_memory,
      memory_usage_mb: Float.round(total_memory / 1_048_576, 2),
      memory_usage_percent: Float.round(total_memory / (@max_memory_mb * 1_048_576) * 100, 1),
      popular_frames: popular_count,
      frames_used_in_gifs: gif_usage_count,
      total_accesses: total_accesses,
      avg_accesses: avg_accesses,
      max_capacity: @max_cache_size,
      max_memory_mb: @max_memory_mb
    }
    
    {:reply, stats, %{state | memory_usage: total_memory}}
  end
  
  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    Logger.info("Frame cache cleared")
    {:reply, :ok, %{state | memory_usage: 0}}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    perform_cleanup()
    schedule_cleanup()
    {:noreply, state}
  end
  
  # Private functions
  
  defp schedule_cleanup() do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
  
  defp perform_cleanup() do
    cache_size = :ets.info(@table_name, :size)
    
    # Calculate actual memory usage
    total_memory = 
      :ets.foldl(fn {_frame_id, {image_data, _access_count, _last_accessed, _metadata}}, acc ->
        acc + byte_size(image_data)
      end, 0, @table_name)
    
    memory_mb = total_memory / 1_048_576
    
    cond do
      memory_mb > @max_memory_mb ->
        # Evict 25% of cache based on LRU, but preserve frames used in GIFs
        evict_count = max(1, div(cache_size, 4))
        evict_multiple_lru_smart(evict_count)
        Logger.info("Evicted #{evict_count} frames due to memory pressure (#{Float.round(memory_mb, 1)}MB)")
        
      cache_size > @max_cache_size ->
        # Evict excess entries
        evict_count = cache_size - @max_cache_size
        evict_multiple_lru_smart(evict_count)
        Logger.info("Evicted #{evict_count} frames due to size limit")
        
      true ->
        # Optional: evict very old, low-access entries
        evict_stale_entries()
    end
  end
  
  
  defp evict_multiple_lru_smart(count) when count > 0 do
    # Get all entries sorted by priority (GIF usage frames are kept longer)
    entries = 
      :ets.foldl(fn {frame_id, {_image_data, access_count, last_accessed, metadata}}, acc ->
        gif_usage = Map.get(metadata, :gif_usage_count, 0)
        # Priority calculation: GIF frames get bonus points, recent access matters
        priority_score = access_count + (gif_usage * 10) - (DateTime.diff(DateTime.utc_now(), last_accessed, :hour))
        [{frame_id, last_accessed, priority_score} | acc]
      end, [], @table_name)
      |> Enum.sort_by(fn {_frame_id, _last_accessed, priority_score} -> 
        priority_score  # Lowest priority gets evicted first
      end)
      |> Enum.take(count)
    
    # Evict the selected entries
    Enum.each(entries, fn {frame_id, _last_accessed, _priority_score} ->
      :ets.delete(@table_name, frame_id)
    end)
  end
  
  defp evict_stale_entries() do
    # Remove entries that haven't been accessed in the last 2 hours and have low access count
    cutoff_time = DateTime.add(DateTime.utc_now(), -7200, :second)  # 2 hours ago
    
    stale_frames = 
      :ets.foldl(fn {frame_id, {_image_data, access_count, last_accessed, metadata}}, acc ->
        gif_usage = Map.get(metadata, :gif_usage_count, 0)
        
        # Don't evict frames that have been used in GIFs or are popular
        if DateTime.compare(last_accessed, cutoff_time) == :lt and access_count < 2 and gif_usage == 0 do
          [frame_id | acc]
        else
          acc
        end
      end, [], @table_name)
    
    if length(stale_frames) > 0 do
      Enum.each(stale_frames, fn frame_id ->
        :ets.delete(@table_name, frame_id)
      end)
      Logger.debug("Evicted #{length(stale_frames)} stale frames from cache")
    end
  end
end