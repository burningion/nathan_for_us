defmodule NathanForUs.Repo.Migrations.CreateVideoSubsystemTables do
  use Ecto.Migration

  def change do
    # Videos table - stores metadata about processed videos
    create table(:videos) do
      add :title, :string, null: false
      add :file_path, :string, null: false
      add :duration_ms, :integer
      add :fps, :float
      add :frame_count, :integer
      add :status, :string, default: "pending" # pending, processing, completed, failed
      add :processed_at, :utc_datetime
      add :metadata, :map # Store additional ffprobe metadata as JSON

      timestamps()
    end

    create unique_index(:videos, [:file_path])
    create index(:videos, [:status])
    create index(:videos, [:processed_at])

    # Video frames table - stores individual frame data
    create table(:video_frames) do
      add :video_id, references(:videos, on_delete: :delete_all), null: false
      add :frame_number, :integer, null: false
      add :timestamp_ms, :integer, null: false
      add :file_path, :string, null: false
      add :file_size, :integer
      add :width, :integer
      add :height, :integer

      timestamps()
    end

    create index(:video_frames, [:video_id])
    create index(:video_frames, [:timestamp_ms])
    create index(:video_frames, [:frame_number])
    create unique_index(:video_frames, [:video_id, :frame_number])

    # Video captions table - stores subtitle/caption data
    create table(:video_captions) do
      add :video_id, references(:videos, on_delete: :delete_all), null: false
      add :start_time_ms, :integer, null: false
      add :end_time_ms, :integer, null: false
      add :text, :text, null: false
      add :caption_index, :integer # Original subtitle index number

      timestamps()
    end

    create index(:video_captions, [:video_id])
    create index(:video_captions, [:start_time_ms])
    create index(:video_captions, [:end_time_ms])

    # Full-text search index on caption text
    # PostgreSQL specific - creates GIN index for text search
    execute """
    CREATE INDEX video_captions_text_search_idx 
    ON video_captions 
    USING GIN (to_tsvector('english', text))
    """, """
    DROP INDEX video_captions_text_search_idx
    """

    # Frame-caption associations - links frames to their captions
    create table(:frame_captions) do
      add :frame_id, references(:video_frames, on_delete: :delete_all), null: false
      add :caption_id, references(:video_captions, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:frame_captions, [:frame_id])
    create index(:frame_captions, [:caption_id])
    create unique_index(:frame_captions, [:frame_id, :caption_id])
  end
end
