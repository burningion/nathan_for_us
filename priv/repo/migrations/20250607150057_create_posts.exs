defmodule NathanForUs.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :content, :text
      add :image_url, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:posts, [:user_id])
    create index(:posts, [:inserted_at])
  end
end
