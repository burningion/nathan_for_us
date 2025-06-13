defmodule NathanForUs.Repo.Migrations.AddGifIdToViralGifs do
  use Ecto.Migration

  def change do
    alter table(:viral_gifs) do
      add :gif_id, references(:gifs, on_delete: :nilify_all)
    end

    create index(:viral_gifs, [:gif_id])
  end
end