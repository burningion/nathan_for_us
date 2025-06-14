defmodule NathanForUs.Config do
  @moduledoc """
  Centralized configuration management for Nathan For Us.

  This module provides a clean interface for accessing application configuration
  with proper defaults and environment-specific overrides.
  """

  @doc """
  Gets video processing configuration.
  """
  def video_processing do
    %{
      default_fps: get_env(:video_processing, :default_fps, 1),
      default_quality: get_env(:video_processing, :default_quality, 3),
      use_hardware_accel: get_env(:video_processing, :use_hardware_accel, true),
      max_concurrent_jobs: get_env(:video_processing, :max_concurrent_jobs, 2),
      frame_output_dir: get_env(:video_processing, :frame_output_dir, "priv/static/frames"),
      check_interval_ms: get_env(:video_processing, :check_interval_ms, 5_000)
    }
  end

  @doc """
  Gets search configuration.
  """
  def search do
    %{
      default_limit: get_env(:search, :default_limit, 50),
      max_results: get_env(:search, :max_results, 1000),
      enable_full_text_search: get_env(:search, :enable_full_text_search, true),
      search_timeout_ms: get_env(:search, :search_timeout_ms, 30_000)
    }
  end

  @doc """
  Gets admin configuration.
  """
  def admin do
    %{
      max_backfill_limit: get_env(:admin, :max_backfill_limit, 1000),
      default_backfill_limit: get_env(:admin, :default_backfill_limit, 50),
      backfill_timeout_ms: get_env(:admin, :backfill_timeout_ms, 300_000),
      stats_cache_ttl_ms: get_env(:admin, :stats_cache_ttl_ms, 60_000)
    }
  end

  @doc """
  Gets Bluesky API configuration.
  """
  def bluesky_api do
    %{
      base_url: get_env(:bluesky_api, :base_url, "https://public.api.bsky.app"),
      timeout_ms: get_env(:bluesky_api, :timeout_ms, 10_000),
      retry_attempts: get_env(:bluesky_api, :retry_attempts, 3),
      retry_delay_ms: get_env(:bluesky_api, :retry_delay_ms, 1_000),
      rate_limit_per_hour: get_env(:bluesky_api, :rate_limit_per_hour, 3000)
    }
  end

  @doc """
  Gets logging configuration.
  """
  def logging do
    %{
      level: get_env(:logger, :level, :info),
      enable_error_tracking: get_env(:logging, :enable_error_tracking, true),
      log_slow_queries: get_env(:logging, :log_slow_queries, true),
      slow_query_threshold_ms: get_env(:logging, :slow_query_threshold_ms, 1000)
    }
  end

  @doc """
  Gets feature flags configuration.
  """
  def feature_flags do
    %{
      video_processing_enabled: get_env(:feature_flags, :video_processing_enabled, true),
      bluesky_integration_enabled: get_env(:feature_flags, :bluesky_integration_enabled, true),
      admin_dashboard_enabled: get_env(:feature_flags, :admin_dashboard_enabled, true),
      frame_animation_enabled: get_env(:feature_flags, :frame_animation_enabled, true),
      search_suggestions_enabled: get_env(:feature_flags, :search_suggestions_enabled, true)
    }
  end

  @doc """
  Gets environment-specific configuration with fallback to default.
  """
  def get_env(app_key, config_key, default \\ nil) do
    Application.get_env(:nathan_for_us, app_key, %{})
    |> Map.get(config_key, default)
  end

  @doc """
  Checks if we're running in development environment.
  """
  def dev? do
    Application.get_env(:nathan_for_us, :environment) == :dev
  end

  @doc """
  Checks if we're running in production environment.
  """
  def prod? do
    Application.get_env(:nathan_for_us, :environment) == :prod
  end

  @doc """
  Checks if we're running in test environment.
  """
  def test? do
    Application.get_env(:nathan_for_us, :environment) == :test
  end

  @doc """
  Gets the current environment.
  """
  def environment do
    Application.get_env(:nathan_for_us, :environment, :dev)
  end

  @doc """
  Validates that required configuration is present.

  Should be called during application startup to fail fast if config is missing.
  """
  def validate_config! do
    required_configs = [
      {:nathan_for_us, NathanForUs.Repo},
      {:nathan_for_us, NathanForUsWeb.Endpoint}
    ]

    Enum.each(required_configs, fn {app, key} ->
      case Application.get_env(app, key) do
        nil ->
          raise "Missing required configuration: #{app}.#{key}"

        _config ->
          :ok
      end
    end)

    # Validate database configuration
    repo_config = Application.get_env(:nathan_for_us, NathanForUs.Repo, [])

    unless Keyword.has_key?(repo_config, :database) do
      raise "Missing database configuration"
    end

    :ok
  end
end
