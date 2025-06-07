defmodule NathanForUs.Social.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :content, :string
    field :image_url, :string
    belongs_to :user, NathanForUs.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:content, :image_url, :user_id])
    |> validate_required([:user_id])
    |> trim_content()
    |> validate_content_or_image()
    |> foreign_key_constraint(:user_id)
  end

  defp trim_content(changeset) do
    case get_change(changeset, :content) do
      nil -> changeset
      content -> put_change(changeset, :content, String.trim(content))
    end
  end

  defp validate_content_or_image(changeset) do
    content = get_field(changeset, :content)
    image_url = get_field(changeset, :image_url)

    if is_nil(content) and is_nil(image_url) do
      add_error(changeset, :content, "must have either content or image")
    else
      changeset
    end
  end
end