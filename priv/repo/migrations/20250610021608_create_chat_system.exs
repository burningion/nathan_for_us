defmodule NathanForUs.Repo.Migrations.CreateChatSystem do
  use Ecto.Migration

  def change do
    create table(:words) do
      add :text, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :submitted_by_id, references(:users, on_delete: :delete_all), null: false
      add :approved_by_id, references(:users, on_delete: :nilify_all), null: true
      add :submission_count, :integer, default: 1
      add :banned_forever, :boolean, default: false

      timestamps()
    end

    create table(:chat_messages) do
      add :content, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:words, [:status])
    create index(:words, [:submitted_by_id])
    create index(:words, [:approved_by_id])
    create index(:words, [:text], unique: true)
    create index(:chat_messages, [:user_id])
    create index(:chat_messages, [:inserted_at])
  end
end
