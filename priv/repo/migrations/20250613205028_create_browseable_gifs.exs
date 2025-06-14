defmodule NathanForUs.Repo.Migrations.CreateBrowseableGifs do
  use Ecto.Migration

  def change do
    create table(:browseable_gifs) do
      add :title, :string
      add :start_frame_index, :integer, null: false
      add :end_frame_index, :integer, null: false
      add :category, :string
      # JSON encoded frame data
      add :frame_data, :text
      add :is_public, :boolean, default: true, null: false

      add :video_id, references(:videos, on_delete: :delete_all), null: false
      add :created_by_user_id, references(:users, on_delete: :nilify_all)
      add :gif_id, references(:gifs, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:browseable_gifs, [:video_id])
    create index(:browseable_gifs, [:created_by_user_id])
    create index(:browseable_gifs, [:gif_id])
    create index(:browseable_gifs, [:category])
    create index(:browseable_gifs, [:is_public])
    create index(:browseable_gifs, [:inserted_at])
    create index(:browseable_gifs, [:video_id, :inserted_at])
  end
end
