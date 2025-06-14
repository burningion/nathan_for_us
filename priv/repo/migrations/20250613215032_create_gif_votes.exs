defmodule NathanForUs.Repo.Migrations.CreateGifVotes do
  use Ecto.Migration

  def change do
    create table(:gif_votes) do
      add :user_id, references(:users, on_delete: :delete_all), null: true
      add :browseable_gif_id, references(:browseable_gifs, on_delete: :delete_all), null: false
      # For anonymous votes
      add :session_id, :string, null: true
      # "up" or "down" for future
      add :vote_type, :string, null: false, default: "up"
      # For spam prevention
      add :ip_address, :string, null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:gif_votes, [:user_id, :browseable_gif_id],
             where: "user_id IS NOT NULL",
             name: :unique_user_gif_vote
           )

    create unique_index(:gif_votes, [:session_id, :browseable_gif_id],
             where: "session_id IS NOT NULL",
             name: :unique_session_gif_vote
           )

    create index(:gif_votes, [:browseable_gif_id])
    create index(:gif_votes, [:inserted_at])

    # Add vote counts to browseable_gifs for efficient querying
    alter table(:browseable_gifs) do
      add :upvotes_count, :integer, default: 0, null: false
      add :downvotes_count, :integer, default: 0, null: false
      add :hot_score, :float, default: 0.0, null: false
      add :hot_score_updated_at, :utc_datetime, default: fragment("now()"), null: false
    end

    create index(:browseable_gifs, [:hot_score])
    create index(:browseable_gifs, [:upvotes_count])
  end
end
