defmodule NathanForUs.Repo.Migrations.AddGifTracking do
  use Ecto.Migration

  def change do
    create table(:viral_gifs) do
      add :title, :string
      add :description, :text
      add :start_frame_index, :integer, null: false
      add :end_frame_index, :integer, null: false
      add :video_id, :integer, null: false
      add :view_count, :integer, default: 0
      add :share_count, :integer, default: 0
      add :created_by_user_id, references(:users, on_delete: :delete_all)
      add :is_featured, :boolean, default: false
      add :category, :string
      add :frame_data, :text # JSON of frame sequence for quick access
      
      timestamps(type: :utc_datetime)
    end

    create index(:viral_gifs, [:video_id])
    create index(:viral_gifs, [:view_count])
    create index(:viral_gifs, [:share_count])
    create index(:viral_gifs, [:category])
    create index(:viral_gifs, [:is_featured])
    create index(:viral_gifs, [:inserted_at])

    # Track GIF interactions
    create table(:gif_interactions) do
      add :viral_gif_id, references(:viral_gifs, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all)
      add :session_id, :string
      add :interaction_type, :string # "view", "share", "download"
      add :platform, :string # "twitter", "instagram", "tiktok", etc.
      
      timestamps(type: :utc_datetime)
    end

    create index(:gif_interactions, [:viral_gif_id])
    create index(:gif_interactions, [:interaction_type])
    create index(:gif_interactions, [:inserted_at])
  end
end