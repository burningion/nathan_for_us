defmodule NathanForUs.Repo.Migrations.AddUserIdToBlueskyPosts do
  use Ecto.Migration

  def change do
    alter table(:bluesky_posts) do
      add :bluesky_user_id, references(:bluesky_users, on_delete: :delete_all)
    end

    create index(:bluesky_posts, [:bluesky_user_id])
  end
end
