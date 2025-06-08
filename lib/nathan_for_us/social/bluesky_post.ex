defmodule NathanForUs.Social.BlueskyPost do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bluesky_posts" do
    field :cid, :string
    field :collection, :string
    field :operation, :string
    field :rkey, :string
    field :rev, :string
    field :record_type, :string
    field :record_created_at, :utc_datetime
    field :record_langs, {:array, :string}
    field :record_text, :string

    belongs_to :bluesky_user, NathanForUs.Social.BlueskyUser

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bluesky_post, attrs) do
    bluesky_post
    |> cast(attrs, [:cid, :collection, :operation, :rkey, :rev, :record_type, :record_created_at, :record_langs, :record_text, :bluesky_user_id])
    |> validate_required([:cid, :collection, :operation])
    |> unique_constraint(:cid)
  end

  @doc """
  Creates a BlueskyPost from the raw record format received from the firehose
  """
  def from_firehose_record(record_data) do
    %{
      cid: record_data["cid"],
      collection: record_data["collection"],
      operation: record_data["operation"],
      rkey: record_data["rkey"],
      rev: record_data["rev"],
      record_type: get_in(record_data, ["record", "$type"]),
      record_created_at: parse_datetime(get_in(record_data, ["record", "createdAt"])),
      record_langs: get_in(record_data, ["record", "langs"]),
      record_text: get_in(record_data, ["record", "text"])
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