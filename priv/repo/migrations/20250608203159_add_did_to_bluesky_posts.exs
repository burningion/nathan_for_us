defmodule NathanForUs.Repo.Migrations.AddDidToBlueskyPosts do
  use Ecto.Migration

  def change do
    alter table(:bluesky_posts) do
      add :did, :string
    end

    create index(:bluesky_posts, [:did])
  end
end
