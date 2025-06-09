defmodule NathanForUs.AdminService do
  @moduledoc """
  Service module providing business logic for administrative operations.
  
  This module handles all admin-related business logic separate from LiveView concerns:
  
  - User access validation and authorization
  - Administrative statistics collection and enrichment
  - Profile backfill operations with validation and error handling
  - Task management and completion processing
  - Parameter parsing and validation
  
  ## Examples
  
      # Validate admin access
      :ok = AdminService.validate_admin_access(user)
      
      # Get enriched statistics
      stats = AdminService.get_admin_stats()
      coverage = AdminService.calculate_profile_coverage(stats)
      
      # Start backfill operation
      options = %{limit: 50, dry_run: true}
      {:ok, task} = AdminService.start_backfill(options)
      
      # Handle completion
      {:ok, results} = AdminService.handle_backfill_completion({:ok, raw_results})
  """
  
  alias NathanForUs.Admin
  
  @type backfill_options :: %{
    limit: integer(),
    dry_run: boolean()
  }
  
  @type backfill_result :: %{
    posts_found: integer(),
    unique_dids: integer(),
    successful: integer(),
    failed: integer(),
    dry_run: boolean()
  }
  
  @type admin_stats :: %{
    total_posts: integer(),
    posts_with_users: integer(),
    posts_without_users: integer(),
    total_users: integer(),
    unique_dids_in_posts: integer()
  }
  
  @doc """
  Validates admin access for a user.
  """
  @spec validate_admin_access(term()) :: :ok | {:error, :access_denied}
  def validate_admin_access(user) do
    if Admin.is_admin?(user) do
      :ok
    else
      {:error, :access_denied}
    end
  end
  
  @doc """
  Gets comprehensive admin statistics.
  """
  @spec get_admin_stats() :: admin_stats()
  def get_admin_stats do
    try do
      stats = Admin.get_stats()
      enrich_stats(stats)
    rescue
      error ->
        %{
          total_posts: 0,
          posts_with_users: 0,
          posts_without_users: 0,
          total_users: 0,
          unique_dids_in_posts: 0,
          error: Exception.message(error)
        }
    end
  end
  
  @doc """
  Validates backfill parameters and starts the operation.
  """
  @spec start_backfill(backfill_options()) :: {:ok, Task.t()} | {:error, String.t()}
  def start_backfill(%{limit: limit, dry_run: dry_run} = options) do
    case validate_backfill_options(options) do
      :ok ->
        task = Task.async(fn ->
          execute_backfill(limit, dry_run)
        end)
        {:ok, task}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Processes backfill task completion.
  """
  @spec handle_backfill_completion(term()) :: {:ok, backfill_result()} | {:error, String.t()}
  def handle_backfill_completion({:ok, results}) do
    enriched_results = enrich_backfill_results(results)
    {:ok, enriched_results}
  end
  
  def handle_backfill_completion({:error, reason}) do
    {:error, format_backfill_error(reason)}
  end
  
  @doc """
  Calculates coverage percentage for profile completion.
  """
  @spec calculate_profile_coverage(admin_stats()) :: float()
  def calculate_profile_coverage(%{total_posts: 0}), do: 0.0
  def calculate_profile_coverage(%{total_posts: total, posts_with_users: with_users}) do
    Float.round(with_users / total * 100, 1)
  end
  
  @doc """
  Validates if a backfill operation can be started.
  """
  @spec can_start_backfill?(boolean()) :: boolean()
  def can_start_backfill?(backfill_running) do
    not backfill_running
  end
  
  @doc """
  Formats backfill options from form parameters.
  """
  @spec parse_backfill_params(map()) :: {:ok, backfill_options()} | {:error, String.t()}
  def parse_backfill_params(%{"limit" => limit_str, "dry_run" => dry_run_str}) do
    try do
      limit = String.to_integer(limit_str)
      dry_run = dry_run_str == "true"
      
      options = %{limit: limit, dry_run: dry_run}
      {:ok, options}
    rescue
      ArgumentError ->
        {:error, "Invalid limit parameter"}
    end
  end
  
  def parse_backfill_params(_params) do
    {:error, "Missing required parameters"}
  end
  
  # Private functions
  
  defp validate_backfill_options(%{limit: limit, dry_run: dry_run}) do
    cond do
      not is_integer(limit) ->
        {:error, "Limit must be an integer"}
      
      limit <= 0 ->
        {:error, "Limit must be greater than 0"}
      
      limit > 1000 ->
        {:error, "Limit cannot exceed 1000"}
      
      not is_boolean(dry_run) ->
        {:error, "Dry run must be true or false"}
      
      true ->
        :ok
    end
  end
  
  defp execute_backfill(limit, dry_run) do
    Admin.backfill_bluesky_profiles(limit: limit, dry_run: dry_run)
  end
  
  defp enrich_stats(stats) do
    Map.merge(stats, %{
      coverage_percentage: calculate_profile_coverage(stats),
      last_updated: DateTime.utc_now()
    })
  end
  
  defp enrich_backfill_results(results) do
    Map.merge(results, %{
      completion_rate: calculate_completion_rate(results),
      timestamp: DateTime.utc_now()
    })
  end
  
  defp calculate_completion_rate(%{successful: successful, failed: failed}) 
       when successful + failed > 0 do
    Float.round(successful / (successful + failed) * 100, 1)
  end
  
  defp calculate_completion_rate(_), do: 0.0
  
  defp format_backfill_error(reason) do
    case reason do
      {:timeout, _} -> "Backfill operation timed out"
      :killed -> "Backfill operation was terminated"
      _ -> "Backfill failed: #{inspect(reason)}"
    end
  end
end