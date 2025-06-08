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
    field :embed_type, :string
    field :embed_uri, :string
    field :embed_title, :string
    field :embed_description, :string
    field :embed_thumb, :string
    field :did, :string

    belongs_to :bluesky_user, NathanForUs.Social.BlueskyUser

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bluesky_post, attrs) do
    bluesky_post
    |> cast(attrs, [:cid, :collection, :operation, :rkey, :rev, :record_type, :record_created_at, :record_langs, :record_text, :embed_type, :embed_uri, :embed_title, :embed_description, :embed_thumb, :did, :bluesky_user_id])
    |> validate_required([:cid, :collection, :operation])
    |> unique_constraint(:cid)
  end

  @doc """
  Creates a BlueskyPost from the raw record format received from the firehose
  """
  def from_firehose_record(record_data) do
    embed_data = extract_embed_data(record_data)
    
    %{
      cid: record_data["cid"],
      collection: record_data["collection"],
      operation: record_data["operation"],
      rkey: record_data["rkey"],
      rev: record_data["rev"],
      record_type: get_in(record_data, ["record", "$type"]),
      record_created_at: parse_datetime(get_in(record_data, ["record", "createdAt"])),
      record_langs: get_in(record_data, ["record", "langs"]),
      record_text: get_in(record_data, ["record", "text"]),
      embed_type: embed_data[:type],
      embed_uri: embed_data[:uri],
      embed_title: embed_data[:title],
      embed_description: embed_data[:description],
      embed_thumb: embed_data[:thumb],
      did: record_data["repo"]
    }
  end

  defp extract_embed_data(record_data) do
    case get_in(record_data, ["record", "embed"]) do
      %{"external" => external} ->
        %{
          type: "external",
          uri: external["uri"],
          title: external["title"],
          description: external["description"],
          thumb: external["thumb"]
        }
      %{"$type" => "app.bsky.embed.external", "external" => external} ->
        %{
          type: "external",
          uri: external["uri"],
          title: external["title"],
          description: external["description"],
          thumb: external["thumb"]
        }
      %{"$type" => "app.bsky.embed.images", "images" => images} when is_list(images) ->
        first_image = List.first(images)
        %{
          type: "images",
          uri: get_in(first_image, ["image", "ref", "$link"]),
          title: first_image["alt"],
          description: nil,
          thumb: get_in(first_image, ["image", "ref", "$link"])
        }
      %{"$type" => "app.bsky.embed.video", "video" => video} ->
        %{
          type: "video",
          uri: get_in(video, ["ref", "$link"]),
          title: video["alt"],
          description: nil,
          thumb: get_in(video, ["thumbnail", "ref", "$link"])
        }
      _ ->
        %{type: nil, uri: nil, title: nil, description: nil, thumb: nil}
    end
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> nil
    end
  end
end