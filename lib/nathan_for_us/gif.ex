defmodule NathanForUs.Gif do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias NathanForUs.{Repo, Video}

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "gifs" do
    field :hash, :string
    field :frame_ids, {:array, :integer}
    field :gif_data, :binary
    field :frame_count, :integer
    field :duration_ms, :integer
    field :file_size, :integer

    belongs_to :video, Video

    timestamps()
  end

  @doc false
  def changeset(gif, attrs) do
    gif
    |> cast(attrs, [:hash, :video_id, :frame_ids, :gif_data, :frame_count, :duration_ms, :file_size])
    |> validate_required([:hash, :video_id, :frame_ids, :gif_data, :frame_count])
    |> unique_constraint(:hash)
    |> foreign_key_constraint(:video_id)
  end

  @doc """
  Generate a hash for a set of frames from a video.
  """
  def generate_hash(video_id, frame_ids) when is_list(frame_ids) do
    # Sort frame IDs to ensure consistent hashing regardless of selection order
    sorted_frame_ids = Enum.sort(frame_ids)
    
    # Create a string representation to hash
    hash_string = "#{video_id}:#{Enum.join(sorted_frame_ids, ",")}"
    
    # Generate SHA256 hash
    :crypto.hash(:sha256, hash_string)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Find an existing GIF by hash.
  """
  def find_by_hash(hash) do
    from(g in __MODULE__, where: g.hash == ^hash)
    |> Repo.one()
  end

  @doc """
  Create a new GIF record in the database.
  """
  def create_gif(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Find or create a GIF for the given frames.
  Returns {:ok, gif} if found, or {:generate, hash} if needs to be generated.
  """
  def find_or_prepare(video_id, frames) when is_list(frames) do
    frame_ids = Enum.map(frames, & &1.id)
    hash = generate_hash(video_id, frame_ids)

    case find_by_hash(hash) do
      nil ->
        {:generate, hash, frame_ids}
      gif ->
        {:ok, gif}
    end
  end

  @doc """
  Save a generated GIF to the database.
  """
  def save_generated_gif(hash, video_id, frame_ids, gif_binary) do
    attrs = %{
      hash: hash,
      video_id: video_id,
      frame_ids: frame_ids,
      gif_data: gif_binary,
      frame_count: length(frame_ids),
      file_size: byte_size(gif_binary)
    }

    create_gif(attrs)
  end

  @doc """
  Get GIF data as base64 string for embedding.
  """
  def to_base64(%__MODULE__{gif_data: gif_data}) when is_binary(gif_data) do
    Base.encode64(gif_data)
  end

  @doc """
  Get recent GIFs for a video.
  """
  def recent_for_video(video_id, limit \\ 10) do
    from(g in __MODULE__,
      where: g.video_id == ^video_id,
      order_by: [desc: g.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Get statistics about stored GIFs.
  """
  def stats do
    from(g in __MODULE__,
      select: %{
        total_count: count(g.id),
        total_size: sum(g.file_size),
        avg_frame_count: avg(g.frame_count)
      }
    )
    |> Repo.one()
  end
end