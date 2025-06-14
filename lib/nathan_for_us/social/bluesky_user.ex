defmodule NathanForUs.Social.BlueskyUser do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bluesky_users" do
    field :did, :string
    field :handle, :string
    field :display_name, :string
    field :description, :string
    field :avatar_url, :string
    field :banner_url, :string
    field :followers_count, :integer
    field :follows_count, :integer
    field :posts_count, :integer
    field :created_at_bluesky, :utc_datetime

    has_many :bluesky_posts, NathanForUs.Social.BlueskyPost

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bluesky_user, attrs) do
    bluesky_user
    |> cast(attrs, [
      :did,
      :handle,
      :display_name,
      :description,
      :avatar_url,
      :banner_url,
      :followers_count,
      :follows_count,
      :posts_count,
      :created_at_bluesky
    ])
    |> validate_required([:did, :handle])
    |> unique_constraint(:did)
    |> unique_constraint(:handle)
  end

  @doc """
  Creates a BlueskyUser from Bluesky API profile data
  """
  def from_api_profile(profile_data) do
    %{
      did: profile_data["did"],
      handle: profile_data["handle"],
      display_name: profile_data["displayName"],
      description: profile_data["description"],
      avatar_url: profile_data["avatar"],
      banner_url: profile_data["banner"],
      followers_count: get_in(profile_data, ["followersCount"]),
      follows_count: get_in(profile_data, ["followsCount"]),
      posts_count: get_in(profile_data, ["postsCount"]),
      created_at_bluesky: parse_datetime(profile_data["createdAt"])
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> nil
    end
  end
end
