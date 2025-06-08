defmodule NathanForUs.Repo.Migrations.CreateBlueskyUsers do
  use Ecto.Migration

  def change do
    create table(:bluesky_users) do
      add :did, :string, null: false
      add :handle, :string, null: false
      add :display_name, :string
      add :description, :text
      add :avatar_url, :string
      add :banner_url, :string
      add :followers_count, :integer
      add :follows_count, :integer
      add :posts_count, :integer
      add :created_at_bluesky, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bluesky_users, [:did])
    create unique_index(:bluesky_users, [:handle])
    create index(:bluesky_users, [:display_name])
  end
end
