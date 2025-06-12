defmodule NathanForUs.Repo.Migrations.CreateGifCache do
  use Ecto.Migration

  def change do
    create table(:gif_cache) do
      # Hash of video_id + frame_ids
      add :cache_key, :string, null: false
      add :video_id, references(:videos, on_delete: :delete_all), null: false
      # Array of frame IDs
      add :frame_ids, {:array, :integer}, null: false
      # The actual GIF file data
      add :gif_data, :binary
      add :file_size, :integer
      add :duration_ms, :integer
      add :frame_count, :integer
      # For cache cleanup
      add :accessed_at, :utc_datetime
      add :access_count, :integer, default: 0

      timestamps()
    end

    create unique_index(:gif_cache, [:cache_key])
    create index(:gif_cache, [:video_id])
    create index(:gif_cache, [:accessed_at])
    create index(:gif_cache, [:access_count])
  end
end
