defmodule NathanForUs.Repo.Migrations.CreateGifsTable do
  use Ecto.Migration

  def change do
    create table(:gifs) do
      add :hash, :string, null: false
      add :video_id, references(:videos, on_delete: :delete_all), null: false
      add :frame_ids, {:array, :integer}, null: false
      add :gif_data, :binary, null: false
      add :frame_count, :integer, null: false
      add :duration_ms, :integer
      add :file_size, :integer

      timestamps()
    end

    create unique_index(:gifs, [:hash])
    create index(:gifs, [:video_id])
    create index(:gifs, [:frame_count])
  end
end
