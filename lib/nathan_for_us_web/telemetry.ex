defmodule NathanForUsWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("nathan_for_us.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("nathan_for_us.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("nathan_for_us.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("nathan_for_us.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("nathan_for_us.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Cache Metrics
      last_value("nathan_for_us.cache.gif.memory_usage_mb",
        description: "GIF cache memory usage in MB"
      ),
      last_value("nathan_for_us.cache.frame.memory_usage_mb", 
        description: "Frame cache memory usage in MB"
      ),
      last_value("nathan_for_us.cache.total.memory_usage_percent",
        description: "Total cache memory usage as percentage of budget"
      ),
      last_value("nathan_for_us.cache.gif.cached_items",
        description: "Number of GIFs in cache"
      ),
      last_value("nathan_for_us.cache.frame.cached_items",
        description: "Number of frames in cache"
      ),
      last_value("nathan_for_us.cache.public_timeline.cached_gifs",
        description: "Number of GIFs cached for public timeline"
      ),
      last_value("nathan_for_us.cache.public_timeline.cache_age_seconds",
        description: "Age of public timeline cache in seconds"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      {__MODULE__, :emit_cache_metrics, []}
    ]
  end

  def emit_cache_metrics do
    try do
      # Get cache statistics
      gif_stats = NathanForUs.GifCache.stats()
      frame_stats = NathanForUs.FrameCache.stats()
      cache_manager_stats = NathanForUs.CacheManager.stats()
      
      # Get public timeline cache stats
      timeline_stats = try do
        NathanForUs.PublicTimelineCache.stats()
      rescue
        _ -> %{cached_gifs_count: 0, cache_age_seconds: 0}
      end

      # Emit telemetry events
      :telemetry.execute([:nathan_for_us, :cache, :gif], %{
        memory_usage_mb: gif_stats.memory_usage_mb,
        cached_items: gif_stats.cached_gifs
      })

      :telemetry.execute([:nathan_for_us, :cache, :frame], %{
        memory_usage_mb: frame_stats.memory_usage_mb,
        cached_items: frame_stats.cached_frames
      })

      :telemetry.execute([:nathan_for_us, :cache, :total], %{
        memory_usage_percent: cache_manager_stats.memory_usage_percent
      })
      
      :telemetry.execute([:nathan_for_us, :cache, :public_timeline], %{
        cached_gifs: timeline_stats.cached_gifs_count || 0,
        cache_age_seconds: timeline_stats.cache_age_seconds || 0
      })
    rescue
      _error ->
        # Cache modules might not be started yet, ignore errors during startup
        :ok
    end
  end
end
