defmodule NathanForUs.CacheManager do
  @moduledoc """
  Centralized cache management for a resource-constrained 4GB RAM system.
  
  Coordinates GIF and Frame caches to ensure total memory usage stays within limits.
  Implements aggressive memory management and smart eviction policies.
  """
  
  use GenServer
  require Logger
  
  @total_cache_memory_mb 384    # Total cache budget: ~9.6% of 4GB RAM
  @memory_check_interval 60_000 # Check memory every minute
  @critical_memory_threshold 0.85  # Trigger emergency eviction at 85% of budget
  @warning_memory_threshold 0.70   # Start preventive eviction at 70% of budget
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get comprehensive cache statistics for monitoring.
  """
  def stats() do
    GenServer.call(__MODULE__, :stats)
  end
  
  @doc """
  Force memory cleanup across all caches.
  """
  def force_cleanup() do
    GenServer.cast(__MODULE__, :force_cleanup)
  end
  
  @doc """
  Get memory usage as percentage of total budget.
  """
  def memory_usage_percent() do
    GenServer.call(__MODULE__, :memory_usage_percent)
  end
  
  @doc """
  Adjust cache limits based on current system load.
  """
  def adjust_limits(load_factor) when load_factor >= 0.0 and load_factor <= 1.0 do
    GenServer.cast(__MODULE__, {:adjust_limits, load_factor})
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    # Schedule periodic memory monitoring
    schedule_memory_check()
    
    Logger.info("Cache manager started - Total budget: #{@total_cache_memory_mb}MB")
    
    {:ok, %{
      gif_cache_limit_mb: 128,
      frame_cache_limit_mb: 256,
      total_budget_mb: @total_cache_memory_mb,
      last_cleanup: DateTime.utc_now()
    }}
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    gif_stats = NathanForUs.GifCache.stats()
    frame_stats = NathanForUs.FrameCache.stats()
    
    total_memory_mb = gif_stats.memory_usage_mb + frame_stats.memory_usage_mb
    memory_usage_percent = (total_memory_mb / @total_cache_memory_mb) * 100
    
    combined_stats = %{
      total_memory_mb: Float.round(total_memory_mb, 2),
      total_budget_mb: @total_cache_memory_mb,
      memory_usage_percent: Float.round(memory_usage_percent, 1),
      memory_status: get_memory_status(memory_usage_percent),
      gif_cache: gif_stats,
      frame_cache: frame_stats,
      cache_efficiency: calculate_overall_efficiency(gif_stats, frame_stats),
      last_cleanup: state.last_cleanup,
      system_recommendations: get_system_recommendations(memory_usage_percent, gif_stats, frame_stats)
    }
    
    {:reply, combined_stats, state}
  end
  
  @impl true
  def handle_call(:memory_usage_percent, _from, state) do
    gif_stats = NathanForUs.GifCache.stats()
    frame_stats = NathanForUs.FrameCache.stats()
    
    total_memory_mb = gif_stats.memory_usage_mb + frame_stats.memory_usage_mb
    usage_percent = (total_memory_mb / @total_cache_memory_mb) * 100
    
    {:reply, Float.round(usage_percent, 1), state}
  end
  
  @impl true
  def handle_cast(:force_cleanup, state) do
    perform_coordinated_cleanup()
    {:noreply, %{state | last_cleanup: DateTime.utc_now()}}
  end
  
  @impl true
  def handle_cast({:adjust_limits, load_factor}, state) do
    # Adjust cache limits based on system load
    # Higher load = more conservative caching
    base_gif_mb = 128
    base_frame_mb = 256
    
    adjustment_factor = 1.0 - (load_factor * 0.3)  # Reduce up to 30% under high load
    
    new_gif_limit = trunc(base_gif_mb * adjustment_factor)
    new_frame_limit = trunc(base_frame_mb * adjustment_factor)
    
    Logger.info("Adjusting cache limits based on load #{load_factor}: GIF #{new_gif_limit}MB, Frame #{new_frame_limit}MB")
    
    {:noreply, %{state | 
      gif_cache_limit_mb: new_gif_limit,
      frame_cache_limit_mb: new_frame_limit
    }}
  end
  
  @impl true
  def handle_info(:memory_check, state) do
    gif_stats = NathanForUs.GifCache.stats()
    frame_stats = NathanForUs.FrameCache.stats()
    
    total_memory_mb = gif_stats.memory_usage_mb + frame_stats.memory_usage_mb
    usage_ratio = total_memory_mb / @total_cache_memory_mb
    
    cond do
      usage_ratio >= @critical_memory_threshold ->
        Logger.warning("Critical cache memory usage: #{Float.round(usage_ratio * 100, 1)}% - Emergency cleanup")
        perform_emergency_eviction()
        
      usage_ratio >= @warning_memory_threshold ->
        Logger.info("High cache memory usage: #{Float.round(usage_ratio * 100, 1)}% - Preventive cleanup")
        perform_preventive_cleanup()
        
      true ->
        Logger.debug("Cache memory usage normal: #{Float.round(usage_ratio * 100, 1)}%")
    end
    
    schedule_memory_check()
    {:noreply, state}
  end
  
  # Private functions
  
  defp schedule_memory_check() do
    Process.send_after(self(), :memory_check, @memory_check_interval)
  end
  
  defp perform_coordinated_cleanup() do
    # Coordinated cleanup that considers both caches
    gif_stats = NathanForUs.GifCache.stats()
    frame_stats = NathanForUs.FrameCache.stats()
    
    total_memory = gif_stats.memory_usage_mb + frame_stats.memory_usage_mb
    
    if total_memory > @total_cache_memory_mb * 0.8 do
      # Clear 25% of each cache if we're over 80% of budget
      gif_evict_count = max(1, div(gif_stats.cached_gifs, 4))
      frame_evict_count = max(1, div(frame_stats.cached_frames, 4))
      
      # Use internal eviction mechanisms (assuming we add these methods)
      GenServer.cast(NathanForUs.GifCache, {:evict_multiple, gif_evict_count})
      GenServer.cast(NathanForUs.FrameCache, {:evict_multiple, frame_evict_count})
      
      Logger.info("Coordinated cleanup: evicted #{gif_evict_count} GIFs, #{frame_evict_count} frames")
    end
  end
  
  defp perform_emergency_eviction() do
    # Aggressive eviction to free up memory immediately
    Logger.warning("Performing emergency cache eviction")
    
    # Clear 50% of both caches
    gif_stats = NathanForUs.GifCache.stats()
    frame_stats = NathanForUs.FrameCache.stats()
    
    gif_evict_count = max(1, div(gif_stats.cached_gifs, 2))
    frame_evict_count = max(1, div(frame_stats.cached_frames, 2))
    
    GenServer.cast(NathanForUs.GifCache, {:evict_multiple, gif_evict_count})
    GenServer.cast(NathanForUs.FrameCache, {:evict_multiple, frame_evict_count})
    
    Logger.warning("Emergency eviction completed: #{gif_evict_count} GIFs, #{frame_evict_count} frames")
  end
  
  defp perform_preventive_cleanup() do
    # Gentle cleanup to prevent hitting critical levels
    gif_stats = NathanForUs.GifCache.stats()
    frame_stats = NathanForUs.FrameCache.stats()
    
    # Focus on the cache using more memory
    if gif_stats.memory_usage_mb > frame_stats.memory_usage_mb do
      gif_evict_count = max(1, div(gif_stats.cached_gifs, 8))
      GenServer.cast(NathanForUs.GifCache, {:evict_multiple, gif_evict_count})
    else
      frame_evict_count = max(1, div(frame_stats.cached_frames, 8))
      GenServer.cast(NathanForUs.FrameCache, {:evict_multiple, frame_evict_count})
    end
  end
  
  defp get_memory_status(usage_percent) do
    cond do
      usage_percent >= 85 -> :critical
      usage_percent >= 70 -> :warning
      usage_percent >= 50 -> :moderate
      true -> :normal
    end
  end
  
  defp calculate_overall_efficiency(gif_stats, frame_stats) do
    total_accesses = gif_stats.total_accesses + frame_stats.total_accesses
    total_items = gif_stats.cached_gifs + frame_stats.cached_frames
    
    if total_items > 0 do
      # Simple efficiency calculation based on access patterns
      avg_access_rate = total_accesses / total_items
      # Scale to 0-100%
      min(100.0, avg_access_rate * 10)
    else
      0.0
    end
  end
  
  defp get_system_recommendations(usage_percent, gif_stats, frame_stats) do
    recommendations = []
    
    recommendations = 
      if usage_percent > 80 do
        ["Consider reducing cache sizes or optimizing GIF compression" | recommendations]
      else
        recommendations
      end
    
    recommendations = 
      if gif_stats.avg_accesses < 2 do
        ["GIF cache hit rate is low - consider adjusting eviction policy" | recommendations]
      else
        recommendations
      end
    
    recommendations = 
      if frame_stats.avg_accesses < 2 do
        ["Frame cache hit rate is low - consider more selective caching" | recommendations]
      else
        recommendations
      end
    
    recommendations = 
      if length(recommendations) == 0 do
        ["Cache performance is optimal"]
      else
        recommendations
      end
    
    recommendations
  end
end