defmodule NathanForUs.GifCache do
  @moduledoc """
  ETS-based cache for GIF binary data.
  
  Caches the most recent and popular GIFs to reduce database load.
  Stores GIF data directly without compression for optimal performance.
  
  Cache key structure: gif_id
  Cache value structure: {gif_data, file_size, access_count, last_accessed}
  """
  
  use GenServer
  require Logger
  
  @table_name :gif_cache
  @max_cache_size 50   # Conservative limit for 4GB RAM system
  @max_memory_mb 128   # Conservative memory target - ~3% of total RAM
  @cleanup_interval 300_000  # 5 minutes
  @popularity_threshold 5    # Access count to be considered "popular"
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get GIF data from cache. Returns binary data or nil if not cached.
  """
  def get(gif_id) when is_integer(gif_id) do
    case :ets.lookup(@table_name, gif_id) do
      [{^gif_id, {gif_data, _file_size, access_count, _last_accessed}}] ->
        # Update access count and timestamp asynchronously
        GenServer.cast(__MODULE__, {:record_access, gif_id, access_count + 1})
        gif_data
        
      [] -> 
        nil
    end
  end
  
  @doc """
  Store GIF data in cache.
  """
  def put(gif_id, gif_data, file_size \\ nil) when is_integer(gif_id) and is_binary(gif_data) do
    GenServer.cast(__MODULE__, {:put, gif_id, gif_data, file_size || byte_size(gif_data)})
  end
  
  @doc """
  Warm cache with recent and popular GIFs from database.
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
  Remove specific GIF from cache.
  """
  def evict(gif_id) when is_integer(gif_id) do
    GenServer.cast(__MODULE__, {:evict, gif_id})
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    # Create ETS table for cache storage
    table = :ets.new(@table_name, [
      :set,           # Each gif_id can only have one entry
      :public,        # Allow direct reads from other processes
      :named_table,   # Use atom name instead of table reference
      {:read_concurrency, true},   # Optimize for concurrent reads
      {:write_concurrency, false}  # Optimize for single writer
    ])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    # Warm cache on startup
    warm_cache()
    
    Logger.info("GIF cache started with table #{inspect(table)}")
    
    {:ok, %{table: table, memory_usage: 0}}
  end
  
  @impl true
  def handle_cast({:put, gif_id, gif_data, file_size}, state) do
    # Check if we need to evict before adding
    current_size = :ets.info(@table_name, :size)
    if current_size >= @max_cache_size do
      evict_multiple_lru(1)
    end
    
    # Store in cache with metadata
    cache_entry = {gif_data, file_size, 1, DateTime.utc_now()}
    :ets.insert(@table_name, {gif_id, cache_entry})
    
    new_memory_usage = state.memory_usage + byte_size(gif_data)
    
    Logger.debug("Cached GIF #{gif_id} (#{byte_size(gif_data)} bytes)")
    
    {:noreply, %{state | memory_usage: new_memory_usage}}
  end
  
  @impl true
  def handle_cast({:record_access, gif_id, new_access_count}, state) do
    case :ets.lookup(@table_name, gif_id) do
      [{^gif_id, {gif_data, file_size, _old_count, _old_time}}] ->
        updated_entry = {gif_data, file_size, new_access_count, DateTime.utc_now()}
        :ets.insert(@table_name, {gif_id, updated_entry})
      [] ->
        # GIF was evicted between lookup and access update
        :ok
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:evict, gif_id}, state) do
    case :ets.lookup(@table_name, gif_id) do
      [{^gif_id, {gif_data, _file_size, _access_count, _last_accessed}}] ->
        :ets.delete(@table_name, gif_id)
        freed_memory = byte_size(gif_data)
        new_memory_usage = max(0, state.memory_usage - freed_memory)
        Logger.debug("Evicted GIF #{gif_id} from cache")
        {:noreply, %{state | memory_usage: new_memory_usage}}
      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:evict_multiple, count}, state) do
    evict_multiple_lru(count)
    {:noreply, state}
  end
  
  @impl true
  def handle_cast(:warm_cache, state) do
    Task.start(fn -> 
      try do
        # Get most recent GIFs
        recent_gifs = NathanForUs.Viral.get_recent_gifs(15)
        
        # Cache GIFs that have data
        cached_count = 
          recent_gifs
          |> Enum.filter(& &1.gif && &1.gif.gif_data)
          |> Enum.take(25)  # Conservative limit for 4GB system
          |> Enum.reduce(0, fn viral_gif, acc ->
            gif = viral_gif.gif
            put(gif.id, gif.gif_data, gif.file_size)
            acc + 1
          end)
        
        Logger.info("Cache warmed with #{cached_count} recent GIFs")
      rescue
        error ->
          Logger.error("Cache warming failed: #{inspect(error)}")
      end
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    cache_size = :ets.info(@table_name, :size)
    
    # Calculate actual memory usage by examining entries
    total_memory = 
      :ets.foldl(fn {_gif_id, {gif_data, _file_size, _access_count, _last_accessed}}, acc ->
        acc + byte_size(gif_data)
      end, 0, @table_name)
    
    # Get access patterns
    {popular_count, total_accesses} = 
      :ets.foldl(fn {_gif_id, {_gif_data, _file_size, access_count, _last_accessed}}, {pop_count, total_acc} ->
        new_pop_count = if access_count >= @popularity_threshold, do: pop_count + 1, else: pop_count
        {new_pop_count, total_acc + access_count}
      end, {0, 0}, @table_name)
    
    avg_accesses = if cache_size > 0, do: Float.round(total_accesses / cache_size, 1), else: 0
    
    stats = %{
      cached_gifs: cache_size,
      memory_usage_bytes: total_memory,
      memory_usage_mb: Float.round(total_memory / 1_048_576, 2),
      memory_usage_percent: Float.round(total_memory / (@max_memory_mb * 1_048_576) * 100, 1),
      popular_gifs: popular_count,
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
    Logger.info("Cache cleared")
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
    # Check memory usage and evict if necessary
    cache_size = :ets.info(@table_name, :size)
    
    # Calculate actual memory usage
    total_memory = 
      :ets.foldl(fn {_gif_id, {gif_data, _file_size, _access_count, _last_accessed}}, acc ->
        acc + byte_size(gif_data)
      end, 0, @table_name)
    
    memory_mb = total_memory / 1_048_576
    
    cond do
      memory_mb > @max_memory_mb ->
        # Evict 25% of cache based on LRU
        evict_count = max(1, div(cache_size, 4))
        evict_multiple_lru(evict_count)
        Logger.info("Evicted #{evict_count} GIFs due to memory pressure (#{Float.round(memory_mb, 1)}MB)")
        
      cache_size > @max_cache_size ->
        # Evict excess entries
        evict_count = cache_size - @max_cache_size
        evict_multiple_lru(evict_count)
        Logger.info("Evicted #{evict_count} GIFs due to size limit")
        
      true ->
        # Optional: evict very old, low-access entries
        evict_stale_entries()
    end
  end
  
  defp evict_least_recently_used() do
    evict_multiple_lru(1)
  end
  
  defp evict_multiple_lru(count) when count > 0 do
    # Get all entries sorted by last access time (oldest first)
    entries = 
      :ets.foldl(fn {gif_id, {_gif_data, _file_size, access_count, last_accessed}}, acc ->
        [{gif_id, last_accessed, access_count} | acc]
      end, [], @table_name)
      |> Enum.sort_by(fn {_gif_id, last_accessed, access_count} -> 
        # Sort by access time, but prefer keeping popular items
        {last_accessed, -access_count}
      end)
      |> Enum.take(count)
    
    # Evict the selected entries
    Enum.each(entries, fn {gif_id, _last_accessed, _access_count} ->
      :ets.delete(@table_name, gif_id)
    end)
  end
  
  defp evict_stale_entries() do
    # Remove entries that haven't been accessed in the last hour and have low access count
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)  # 1 hour ago
    
    stale_gifs = 
      :ets.foldl(fn {gif_id, {_gif_data, _file_size, access_count, last_accessed}}, acc ->
        if DateTime.compare(last_accessed, cutoff_time) == :lt and access_count < 3 do
          [gif_id | acc]
        else
          acc
        end
      end, [], @table_name)
    
    if length(stale_gifs) > 0 do
      Enum.each(stale_gifs, fn gif_id ->
        :ets.delete(@table_name, gif_id)
      end)
      Logger.debug("Evicted #{length(stale_gifs)} stale GIFs from cache")
    end
  end
  
end