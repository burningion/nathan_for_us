defmodule NathanForUs.Viral.GifVote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gif_votes" do
    belongs_to :user, NathanForUs.Accounts.User
    belongs_to :browseable_gif, NathanForUs.Viral.BrowseableGif
    field :session_id, :string
    field :vote_type, :string, default: "up"
    field :ip_address, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(gif_vote, attrs) do
    gif_vote
    |> cast(attrs, [:user_id, :browseable_gif_id, :session_id, :vote_type, :ip_address])
    |> validate_required([:browseable_gif_id, :vote_type])
    |> validate_inclusion(:vote_type, ["up", "down"])
    |> validate_vote_source()
    |> unique_constraint([:user_id, :browseable_gif_id], name: :unique_user_gif_vote)
    |> unique_constraint([:session_id, :browseable_gif_id], name: :unique_session_gif_vote)
  end

  defp validate_vote_source(changeset) do
    user_id = get_field(changeset, :user_id)
    session_id = get_field(changeset, :session_id)

    if is_nil(user_id) and is_nil(session_id) do
      add_error(changeset, :base, "Must have either user_id or session_id")
    else
      changeset
    end
  end
end