defmodule Mix.Tasks.Assets.SetupWorker do
  @moduledoc """
  Mix task to copy gif.worker.js to static directory.
  
  This ensures the worker file is available for client-side GIF generation.
  """
  
  use Mix.Task
  
  @shortdoc "Copy gif.worker.js to static directory"
  
  def run(_args) do
    Mix.shell().info("Setting up gif.worker.js...")
    
    # Define paths
    assets_dir = Path.join([File.cwd!(), "assets"])
    worker_source = Path.join([assets_dir, "node_modules", "gif.js", "dist", "gif.worker.js"])
    static_dir = Path.join([File.cwd!(), "priv", "static"])
    worker_target = Path.join([static_dir, "gif.worker.js"])
    
    Mix.shell().info("Source: #{worker_source}")
    Mix.shell().info("Target: #{worker_target}")
    
    # Ensure static directory exists
    File.mkdir_p!(static_dir)
    
    # Copy worker file if source exists
    case File.exists?(worker_source) do
      true ->
        case File.copy(worker_source, worker_target) do
          {:ok, _bytes} ->
            Mix.shell().info("✅ Successfully copied gif.worker.js")
            
            # Verify the copy
            case File.stat(worker_target) do
              {:ok, %{size: size}} ->
                Mix.shell().info("✅ Verified: #{size} bytes written")
                :ok
              {:error, reason} ->
                Mix.shell().error("❌ Verification failed: #{reason}")
                {:error, reason}
            end
            
          {:error, reason} ->
            Mix.shell().error("❌ Copy failed: #{reason}")
            {:error, reason}
        end
        
      false ->
        Mix.shell().error("❌ Source file not found: #{worker_source}")
        
        # Try to find it elsewhere
        gif_js_dir = Path.join([assets_dir, "node_modules", "gif.js"])
        if File.exists?(gif_js_dir) do
          Mix.shell().info("Searching for gif.worker.js in gif.js module...")
          find_worker_file(gif_js_dir, worker_target)
        else
          Mix.shell().error("❌ gif.js module not found")
          {:error, :not_found}
        end
    end
  end
  
  defp find_worker_file(dir, target) do
    case File.ls(dir) do
      {:ok, files} ->
        # Look for gif.worker.js in all subdirectories
        found = Enum.find_value(files, fn file ->
          full_path = Path.join(dir, file)
          cond do
            file == "gif.worker.js" -> 
              full_path
            File.dir?(full_path) and file in ["dist", "lib", "src"] ->
              case File.ls(full_path) do
                {:ok, subfiles} ->
                  if "gif.worker.js" in subfiles do
                    Path.join(full_path, "gif.worker.js")
                  else
                    nil
                  end
                _ -> nil
              end
            true -> nil
          end
        end)
        
        case found do
          nil ->
            Mix.shell().error("❌ gif.worker.js not found in gif.js module")
            {:error, :not_found}
          path ->
            Mix.shell().info("Found gif.worker.js at: #{path}")
            case File.copy(path, target) do
              {:ok, _} ->
                Mix.shell().info("✅ Successfully copied from alternative location")
                :ok
              {:error, reason} ->
                Mix.shell().error("❌ Copy from alternative location failed: #{reason}")
                {:error, reason}
            end
        end
        
      {:error, reason} ->
        Mix.shell().error("❌ Could not list directory #{dir}: #{reason}")
        {:error, reason}
    end
  end
end