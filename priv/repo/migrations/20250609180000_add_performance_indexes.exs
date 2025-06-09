defmodule NathanForUs.Repo.Migrations.AddPerformanceIndexes do
  @moduledoc """
  Adds essential database indexes for video search performance.
  
  This migration creates only the most critical indexes:
  - Full-text search on video captions 
  - Video status filtering
  - Basic social relationship indexes
  """
  
  use Ecto.Migration

  def up do
    # Enable trigram extension for full-text search if not already enabled
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    
    # Only create essential indexes that don't already exist
    execute "CREATE INDEX IF NOT EXISTS video_captions_text_trgm_idx ON video_captions USING gin (text gin_trgm_ops)"
    execute "CREATE INDEX IF NOT EXISTS videos_status_idx ON videos (status)"
    execute "CREATE INDEX IF NOT EXISTS users_is_admin_idx ON users (is_admin)"
  end

  def down do
    # Drop only the indexes we created
    execute "DROP INDEX IF EXISTS video_captions_text_trgm_idx"
    execute "DROP INDEX IF EXISTS videos_status_idx" 
    execute "DROP INDEX IF EXISTS users_is_admin_idx"
  end
end