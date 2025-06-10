defmodule NathanForUs.Repo.Migrations.AddValidToChatMessages do
  use Ecto.Migration

  def change do
    alter table(:chat_messages) do
      add :valid, :boolean, null: false, default: true
    end

    create index(:chat_messages, [:valid])
  end
end
