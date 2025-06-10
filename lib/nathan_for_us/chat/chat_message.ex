defmodule NathanForUs.Chat.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  alias NathanForUs.Accounts.User

  schema "chat_messages" do
    field :content, :string
    field :valid, :boolean, default: true

    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:content, :user_id, :valid])
    |> validate_required([:content, :user_id])
    |> validate_length(:content, min: 1, max: 500)
    |> foreign_key_constraint(:user_id)
  end
end