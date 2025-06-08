defmodule NathanForUs.Repo.Migrations.CreateBlueskyPosts do
  use Ecto.Migration

  def change do
    create table(:bluesky_posts) do
      add :cid, :string, null: false
      add :collection, :string, null: false
      add :operation, :string, null: false
      add :rkey, :string
      add :rev, :string
      add :record_type, :string
      add :record_created_at, :utc_datetime
      add :record_langs, {:array, :string}
      add :record_text, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bluesky_posts, [:cid])
    create index(:bluesky_posts, [:collection])
    create index(:bluesky_posts, [:operation])
    create index(:bluesky_posts, [:record_created_at])
  end
end
