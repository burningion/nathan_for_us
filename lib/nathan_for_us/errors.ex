defmodule NathanForUs.Errors do
  @moduledoc """
  Centralized error handling and custom error types for Nathan For Us.
  
  This module provides:
  - Custom error types for domain-specific errors
  - Error formatting and normalization
  - Logging helpers for consistent error reporting
  - Error recovery strategies
  """

  defmodule VideoProcessingError do
    @moduledoc "Error raised during video processing operations"
    defexception [:message, :video_path, :stage, :reason]
    
    @impl true
    def exception(opts) do
      video_path = Keyword.get(opts, :video_path, "unknown")
      stage = Keyword.get(opts, :stage, "unknown")
      reason = Keyword.get(opts, :reason, "unknown error")
      
      message = "Video processing failed at #{stage} for #{video_path}: #{reason}"
      
      %__MODULE__{
        message: message,
        video_path: video_path,
        stage: stage,
        reason: reason
      }
    end
  end

  defmodule SearchError do
    @moduledoc "Error raised during video search operations"
    defexception [:message, :query, :search_mode, :reason]
    
    @impl true
    def exception(opts) do
      query = Keyword.get(opts, :query, "")
      search_mode = Keyword.get(opts, :search_mode, :unknown)
      reason = Keyword.get(opts, :reason, "unknown error")
      
      message = "Search failed for query '#{query}' in #{search_mode} mode: #{reason}"
      
      %__MODULE__{
        message: message,
        query: query,
        search_mode: search_mode,
        reason: reason
      }
    end
  end

  defmodule AdminError do
    @moduledoc "Error raised during admin operations"
    defexception [:message, :operation, :reason]
    
    @impl true
    def exception(opts) do
      operation = Keyword.get(opts, :operation, "unknown")
      reason = Keyword.get(opts, :reason, "unknown error")
      
      message = "Admin operation failed: #{operation} - #{reason}"
      
      %__MODULE__{
        message: message,
        operation: operation,
        reason: reason
      }
    end
  end

  @doc """
  Normalizes errors to a consistent format.
  
  Takes various error types and returns a standardized error tuple.
  """
  @spec normalize_error(term()) :: {:error, String.t()}
  def normalize_error(%Ecto.Changeset{} = changeset) do
    errors = 
      changeset
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)
      |> format_changeset_errors()
    
    {:error, "Validation failed: #{errors}"}
  end
  
  def normalize_error(%{__exception__: true} = exception) do
    {:error, Exception.message(exception)}
  end
  
  def normalize_error({:error, %Ecto.Changeset{} = changeset}) do
    normalize_error(changeset)
  end
  
  def normalize_error({:error, reason}) when is_binary(reason) do
    {:error, reason}
  end
  
  def normalize_error({:error, reason}) do
    {:error, inspect(reason)}
  end
  
  def normalize_error(error) do
    {:error, inspect(error)}
  end

  @doc """
  Logs an error with contextual information.
  
  Provides consistent error logging across the application.
  """
  @spec log_error(String.t(), term(), keyword()) :: :ok
  def log_error(context, error, metadata \\ []) do
    require Logger
    
    normalized_error = normalize_error(error)
    error_message = elem(normalized_error, 1)
    
    metadata_string = 
      metadata
      |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end)
      |> Enum.join(" ")
    
    full_message = "#{context}: #{error_message}"
    full_message = if metadata_string != "", do: "#{full_message} [#{metadata_string}]", else: full_message
    
    Logger.error(full_message)
  end

  @doc """
  Attempts to recover from an error using a fallback function.
  
  If the primary operation fails, executes the fallback and logs the recovery.
  """
  @spec with_fallback(function(), function(), String.t()) :: term()
  def with_fallback(primary_fn, fallback_fn, context \\ "operation") do
    try do
      primary_fn.()
    rescue
      error ->
        log_error("#{context} failed, attempting fallback", error)
        fallback_fn.()
    catch
      :exit, reason ->
        log_error("#{context} exited, attempting fallback", {:exit, reason})
        fallback_fn.()
      
      :throw, value ->
        log_error("#{context} threw, attempting fallback", {:throw, value})
        fallback_fn.()
    end
  end

  # Private helper functions

  defp format_changeset_errors(errors) when is_map(errors) do
    errors
    |> Enum.map(fn {field, field_errors} ->
      "#{field}: #{Enum.join(field_errors, ", ")}"
    end)
    |> Enum.join("; ")
  end
end