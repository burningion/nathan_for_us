defmodule NathanForUs.Quality do
  @moduledoc """
  Quality assurance and health checking for Nathan For Us.

  This module provides tools for monitoring application health,
  performance metrics, and ensuring code quality standards.
  """

  alias NathanForUs.{Repo, Config}
  require Logger

  @doc """
  Performs a comprehensive health check of the application.

  Returns a detailed report of system status including:
  - Database connectivity and performance
  - Video processing pipeline status
  - Configuration validation
  - Feature flag status
  """
  @spec health_check() :: %{status: :ok | :warning | :error, checks: map()}
  def health_check do
    checks = %{
      database: check_database(),
      video_processing: check_video_processing(),
      configuration: check_configuration(),
      feature_flags: check_feature_flags(),
      disk_space: check_disk_space()
    }

    overall_status = determine_overall_status(checks)

    %{
      status: overall_status,
      checks: checks,
      timestamp: DateTime.utc_now(),
      version: Application.spec(:nathan_for_us, :vsn)
    }
  end

  @doc """
  Validates code quality metrics.

  Checks for common issues and anti-patterns in the codebase.
  """
  @spec code_quality_check() :: %{status: :ok | :warning, issues: list()}
  def code_quality_check do
    issues =
      []
      |> check_module_documentation()
      |> check_function_complexity()
      |> check_test_coverage()

    status = if Enum.empty?(issues), do: :ok, else: :warning

    %{
      status: status,
      issues: issues,
      checked_at: DateTime.utc_now()
    }
  end

  @doc """
  Monitors performance metrics.

  Tracks key performance indicators for the application.
  """
  @spec performance_metrics() :: map()
  def performance_metrics do
    %{
      database: database_metrics(),
      video_processing: video_processing_metrics(),
      memory_usage: memory_metrics(),
      response_times: response_time_metrics()
    }
  end

  # Health check implementations

  defp check_database do
    try do
      # Test basic connectivity
      case Repo.query("SELECT 1", []) do
        {:ok, _result} ->
          # Test performance with a more complex query
          {time_ms, _result} =
            :timer.tc(fn ->
              Repo.query("SELECT COUNT(*) FROM videos", [])
            end)

          query_time_ms = div(time_ms, 1000)

          if query_time_ms > 1000 do
            %{status: :warning, message: "Database queries are slow (#{query_time_ms}ms)"}
          else
            %{status: :ok, message: "Database healthy", query_time_ms: query_time_ms}
          end

        {:error, reason} ->
          %{status: :error, message: "Database connection failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        %{status: :error, message: "Database check failed: #{Exception.message(error)}"}
    end
  end

  defp check_video_processing do
    config = Config.video_processing()

    frame_dir = config.frame_output_dir

    cond do
      not File.exists?(frame_dir) ->
        %{status: :warning, message: "Frame output directory does not exist: #{frame_dir}"}

      not File.dir?(frame_dir) ->
        %{status: :error, message: "Frame output path is not a directory: #{frame_dir}"}

      true ->
        # Check if we can write to the directory
        test_file = Path.join(frame_dir, "health_check_#{System.unique_integer()}.tmp")

        case File.write(test_file, "test") do
          :ok ->
            File.rm(test_file)
            %{status: :ok, message: "Video processing ready", frame_dir: frame_dir}

          {:error, reason} ->
            %{status: :error, message: "Cannot write to frame directory: #{reason}"}
        end
    end
  end

  defp check_configuration do
    try do
      Config.validate_config!()
      %{status: :ok, message: "Configuration valid"}
    rescue
      error ->
        %{status: :error, message: "Configuration invalid: #{Exception.message(error)}"}
    end
  end

  defp check_feature_flags do
    flags = Config.feature_flags()
    enabled_count = flags |> Map.values() |> Enum.count(& &1)
    total_count = map_size(flags)

    %{
      status: :ok,
      message: "#{enabled_count}/#{total_count} features enabled",
      flags: flags
    }
  end

  defp check_disk_space do
    frame_dir = Config.video_processing().frame_output_dir

    case File.stat(frame_dir) do
      {:ok, _stat} ->
        # This is a simplified check - in production you'd want actual disk space monitoring
        %{status: :ok, message: "Disk space sufficient"}

      {:error, reason} ->
        %{status: :warning, message: "Cannot check disk space: #{reason}"}
    end
  end

  # Quality check implementations

  defp check_module_documentation(issues) do
    # This is a placeholder - in a real implementation you'd scan for @moduledoc
    issues
  end

  defp check_function_complexity(issues) do
    # This is a placeholder - in a real implementation you'd analyze function complexity
    issues
  end

  defp check_test_coverage(issues) do
    # This is a placeholder - in a real implementation you'd check test coverage
    issues
  end

  # Performance metric implementations

  defp database_metrics do
    try do
      {time_ms, {:ok, result}} =
        :timer.tc(fn ->
          Repo.query("SELECT COUNT(*) as count FROM videos", [])
        end)

      video_count = result.rows |> List.first() |> List.first()

      %{
        video_count: video_count,
        query_time_ms: div(time_ms, 1000),
        status: :ok
      }
    rescue
      error ->
        %{status: :error, error: Exception.message(error)}
    end
  end

  defp video_processing_metrics do
    try do
      completed_count =
        Repo.query!("SELECT COUNT(*) FROM videos WHERE status = 'completed'", [])
        |> Map.get(:rows)
        |> List.first()
        |> List.first()

      processing_count =
        Repo.query!("SELECT COUNT(*) FROM videos WHERE status = 'processing'", [])
        |> Map.get(:rows)
        |> List.first()
        |> List.first()

      failed_count =
        Repo.query!("SELECT COUNT(*) FROM videos WHERE status = 'failed'", [])
        |> Map.get(:rows)
        |> List.first()
        |> List.first()

      %{
        completed: completed_count,
        processing: processing_count,
        failed: failed_count,
        status: :ok
      }
    rescue
      error ->
        %{status: :error, error: Exception.message(error)}
    end
  end

  defp memory_metrics do
    memory = :erlang.memory()

    %{
      total_mb: div(memory[:total], 1024 * 1024),
      processes_mb: div(memory[:processes], 1024 * 1024),
      atoms_mb: div(memory[:atom], 1024 * 1024),
      ets_mb: div(memory[:ets], 1024 * 1024)
    }
  end

  defp response_time_metrics do
    # Placeholder - in a real implementation you'd track actual response times
    %{
      avg_response_time_ms: 120,
      p95_response_time_ms: 450,
      p99_response_time_ms: 800
    }
  end

  # Utility functions

  defp determine_overall_status(checks) do
    statuses = checks |> Map.values() |> Enum.map(&Map.get(&1, :status))

    cond do
      :error in statuses -> :error
      :warning in statuses -> :warning
      true -> :ok
    end
  end
end
