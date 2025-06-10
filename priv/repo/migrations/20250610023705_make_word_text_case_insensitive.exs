defmodule NathanForUs.Repo.Migrations.MakeWordTextCaseInsensitive do
  use Ecto.Migration

  def change do
    # Add a function-based index for case-insensitive lookups
    create index(:words, ["lower(text)"], name: :words_text_lower_index)
  end
end
