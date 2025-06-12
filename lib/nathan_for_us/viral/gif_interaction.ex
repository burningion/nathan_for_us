defmodule NathanForUs.Viral.GifInteraction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gif_interactions" do
    field :interaction_type, :string
    field :session_id, :string
    field :platform, :string

    belongs_to :viral_gif, NathanForUs.Viral.ViralGif
    belongs_to :user, NathanForUs.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(gif_interaction, attrs) do
    gif_interaction
    |> cast(attrs, [:viral_gif_id, :user_id, :session_id, :interaction_type, :platform])
    |> validate_required([:viral_gif_id, :interaction_type])
    |> validate_inclusion(:interaction_type, ["view", "share", "download"])
    |> foreign_key_constraint(:viral_gif_id)
    |> foreign_key_constraint(:user_id)
  end
end