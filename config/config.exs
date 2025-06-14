# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :nathan_for_us,
  ecto_repos: [NathanForUs.Repo],
  generators: [timestamp_type: :utc_datetime],
  environment: config_env()

# Video processing configuration
config :nathan_for_us, :video_processing,
  default_fps: 1,
  default_quality: 3,
  use_hardware_accel: true,
  max_concurrent_jobs: 2,
  frame_output_dir: "priv/static/frames",
  check_interval_ms: 5_000

# Search configuration
config :nathan_for_us, :search,
  default_limit: 50,
  max_results: 1000,
  enable_full_text_search: true,
  search_timeout_ms: 30_000

# Admin configuration
config :nathan_for_us, :admin,
  max_backfill_limit: 1000,
  default_backfill_limit: 50,
  backfill_timeout_ms: 300_000,
  stats_cache_ttl_ms: 60_000

# Bluesky API configuration
config :nathan_for_us, :bluesky_api,
  base_url: "https://public.api.bsky.app",
  timeout_ms: 10_000,
  retry_attempts: 3,
  retry_delay_ms: 1_000,
  rate_limit_per_hour: 3000

# Logging configuration
config :nathan_for_us, :logging,
  enable_error_tracking: true,
  log_slow_queries: true,
  slow_query_threshold_ms: 1000

# Feature flags
config :nathan_for_us, :feature_flags,
  video_processing_enabled: true,
  bluesky_integration_enabled: true,
  admin_dashboard_enabled: true,
  frame_animation_enabled: true,
  search_suggestions_enabled: true

# Analytics configuration
# Google Analytics ID (set in environment-specific configs)
config :nathan_for_us, :google_analytics_id, nil

# Configures the endpoint
config :nathan_for_us, NathanForUsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: NathanForUsWeb.ErrorHTML, json: NathanForUsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: NathanForUs.PubSub,
  live_view: [signing_salt: "Lm8XxbI5"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :nathan_for_us, NathanForUs.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  nathan_for_us: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  nathan_for_us: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure MIME types for file uploads
config :mime, :types, %{
  "video/x-matroska" => ["mkv"],
  "application/x-subrip" => ["srt"],
  "text/vtt" => ["vtt"]
}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
