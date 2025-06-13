defmodule NathanForUs.Repo.Migrations.AddGifPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Optimize hash lookups for cache hits (most important for high traffic)
    create_if_not_exists index(:gifs, [:hash], unique: true, name: :gifs_hash_unique_idx)
    
    # Optimize queries by video_id for statistics and recent GIFs (may already exist)
    create_if_not_exists index(:gifs, [:video_id])
    
    # Optimize queries by insertion time for recent activity monitoring
    create_if_not_exists index(:gifs, [:inserted_at])
    
    # Optimize file size queries for cache statistics
    create_if_not_exists index(:gifs, [:file_size])
    
    # Composite index for video + recent activity (cache_stats function)
    create_if_not_exists index(:gifs, [:video_id, :inserted_at])
  end
end