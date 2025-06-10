defmodule NathanForUs.Chat.Word do
  use Ecto.Schema
  import Ecto.Changeset

  alias NathanForUs.Accounts.User

  schema "words" do
    field :text, :string
    field :status, :string, default: "pending"
    field :submission_count, :integer, default: 1
    field :banned_forever, :boolean, default: false

    belongs_to :submitted_by, User
    belongs_to :approved_by, User

    timestamps()
  end

  @doc false
  def changeset(word, attrs) do
    word
    |> cast(attrs, [:text, :status, :submission_count, :banned_forever, :submitted_by_id, :approved_by_id])
    |> validate_required([:text, :status, :submitted_by_id])
    |> validate_inclusion(:status, ["pending", "approved", "denied"])
    |> validate_length(:text, min: 1, max: 50)
    |> unique_constraint(:text)
    |> foreign_key_constraint(:submitted_by_id)
    |> foreign_key_constraint(:approved_by_id)
  end
end