defmodule NathanForUs.Repo.Migrations.AddEmbedFieldsToBlueskyPosts do
  use Ecto.Migration

  def change do
    alter table(:bluesky_posts) do
      add :embed_type, :string
      add :embed_uri, :string
      add :embed_title, :string
      add :embed_description, :string
      add :embed_thumb, :string
    end
  end
end
