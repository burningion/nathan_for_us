defmodule NathanForUs.PublicTimelineCache do
  @moduledoc """
  Specialized cache for public timeline GIFs to ensure fast page loads.
  
  This cache pre-loads and stores the most recent GIFs that appear on /public-timeline,
  including their associated data (video info, user info, GIF binary data).
  """
  
  use GenServer
  require Logger
  
  alias NathanForUs.{Viral, GifCache}
  
  @cache_key :public_timeline_gifs
  @cache_size 30  # Cache slightly more than the 25 displayed
  @refresh_interval 60_000  # Refresh every minute
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get cached GIFs for public timeline. Returns cached data or fetches fresh if not available.
  """
  def get_timeline_gifs(limit \\ 25) do
    case :ets.lookup(:public_timeline_cache, @cache_key) do
      [{@cache_key, cached_gifs, _timestamp}] ->
        Logger.debug("Serving public timeline from cache (#{length(cached_gifs)} GIFs)")
        Enum.take(cached_gifs, limit)
      [] ->
        Logger.info("Public timeline cache miss - fetching fresh data")
        refresh_and_get(limit)
    end
  end
  
  @doc """
  Force refresh the cache (called when new GIFs are posted).
  """
  def refresh_cache() do
    GenServer.cast(__MODULE__, :refresh_cache)
  end
  
  @doc """
  Get cache statistics.
  """
  def stats() do
    GenServer.call(__MODULE__, :stats)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    # Create ETS table for cache
    :ets.new(:public_timeline_cache, [
      :set,
      :public,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, false}
    ])
    
    # Initial cache load
    GenServer.cast(self(), :refresh_cache)
    
    # Schedule periodic refresh
    schedule_refresh()
    
    Logger.info("Public timeline cache started")
    
    {:ok, %{last_refresh: DateTime.utc_now(), refresh_count: 0}}
  end
  
  @impl true
  def handle_cast(:refresh_cache, state) do
    perform_cache_refresh()
    
    new_state = %{
      last_refresh: DateTime.utc_now(),
      refresh_count: state.refresh_count + 1
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    cache_info = case :ets.lookup(:public_timeline_cache, @cache_key) do
      [{@cache_key, cached_gifs, timestamp}] ->
        %{
          cached_gifs_count: length(cached_gifs),
          cache_timestamp: timestamp,
          cache_age_seconds: DateTime.diff(DateTime.utc_now(), timestamp, :second)
        }
      [] ->
        %{
          cached_gifs_count: 0,
          cache_timestamp: nil,
          cache_age_seconds: nil
        }
    end
    
    stats = Map.merge(cache_info, %{
      last_refresh: state.last_refresh,
      refresh_count: state.refresh_count,
      cache_size_limit: @cache_size
    })
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_info(:refresh, state) do
    perform_cache_refresh()
    schedule_refresh()
    
    new_state = %{state | 
      last_refresh: DateTime.utc_now(),
      refresh_count: state.refresh_count + 1
    }
    
    {:noreply, new_state}
  end
  
  # Private functions
  
  defp schedule_refresh() do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
  
  defp refresh_and_get(limit) do
    perform_cache_refresh()
    
    case :ets.lookup(:public_timeline_cache, @cache_key) do
      [{@cache_key, cached_gifs, _timestamp}] ->
        Enum.take(cached_gifs, limit)
      [] ->
        # Fallback to direct database query
        Logger.warning("Cache refresh failed, falling back to direct query")
        Viral.get_recent_gifs(limit)
    end
  end
  
  defp perform_cache_refresh() do
    try do
      # Fetch recent GIFs with all associations
      gifs = Viral.get_recent_gifs(@cache_size)
      
      # Pre-cache the GIF binary data in the GIF cache
      gif_cache_tasks = Task.async_stream(gifs, fn viral_gif ->
        if viral_gif.gif && viral_gif.gif.gif_data do
          GifCache.put(viral_gif.gif.id, viral_gif.gif.gif_data, viral_gif.gif.file_size)
          :cached
        else
          :no_data
        end
      end, max_concurrency: 5, timeout: 10_000)
      
      # Count successful cache operations
      cached_count = 
        gif_cache_tasks
        |> Enum.count(fn {:ok, result} -> result == :cached; _ -> false end)
      
      # Store in timeline cache
      timestamp = DateTime.utc_now()
      :ets.insert(:public_timeline_cache, {@cache_key, gifs, timestamp})
      
      Logger.info("Public timeline cache refreshed: #{length(gifs)} GIFs loaded, #{cached_count} GIF binaries cached")
      
    rescue
      error ->
        Logger.error("Failed to refresh public timeline cache: #{inspect(error)}")
    end
  end
end