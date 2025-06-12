defmodule NathanForUs.Video.GifCache do
  @moduledoc """
  Schema and functions for caching generated GIFs based on video frame selections.

  This module provides caching functionality for GIFs generated from specific frame
  selections on videos. It uses a hash of video_id + frame_ids as the cache key.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias NathanForUs.Repo
  alias NathanForUs.Video.Video

  schema "gif_cache" do
    field :cache_key, :string
    field :frame_ids, {:array, :integer}
    field :gif_data, :binary
    field :file_size, :integer
    field :duration_ms, :integer
    field :frame_count, :integer
    field :accessed_at, :utc_datetime
    field :access_count, :integer, default: 0

    belongs_to :video, Video

    timestamps()
  end

  @doc false
  def changeset(gif_cache, attrs) do
    gif_cache
    |> cast(attrs, [
      :cache_key,
      :video_id,
      :frame_ids,
      :gif_data,
      :file_size,
      :duration_ms,
      :frame_count,
      :accessed_at,
      :access_count
    ])
    |> validate_required([:cache_key, :video_id, :frame_ids])
    |> unique_constraint(:cache_key)
    |> foreign_key_constraint(:video_id)
  end

  @doc """
  Generates a cache key from video_id and frame_ids.

  ## Examples

      iex> NathanForUs.Video.GifCache.generate_cache_key(1, [100, 101, 102])
      "6d8b9c8e2a1f4e5d7c9b0a3e2f1d8c7b"
  """
  def generate_cache_key(video_id, frame_ids) when is_integer(video_id) and is_list(frame_ids) do
    # Sort frame IDs to ensure consistent hashing regardless of order
    sorted_frame_ids = Enum.sort(frame_ids)

    # Create hash input string
    hash_input = "video:#{video_id}:frames:#{Enum.join(sorted_frame_ids, ",")}"

    # Generate MD5 hash
    :crypto.hash(:md5, hash_input)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Looks up a cached GIF by video_id and frame_ids.

  Returns the cached GIF if found, otherwise returns nil.
  Updates access tracking when found.
  """
  def lookup_cache(video_id, frame_ids) do
    cache_key = generate_cache_key(video_id, frame_ids)

    case Repo.get_by(__MODULE__, cache_key: cache_key) do
      nil ->
        nil

      gif_cache ->
        # Update access tracking
        update_access_tracking(gif_cache)
        gif_cache
    end
  end

  @doc """
  Stores a GIF in the cache.

  ## Parameters
  - video_id: The video ID
  - frame_ids: List of frame IDs used to generate the GIF
  - gif_data: Binary data of the generated GIF
  - opts: Optional metadata (file_size, duration_ms, frame_count)
  """
  def store_cache(video_id, frame_ids, gif_data, opts \\ []) do
    cache_key = generate_cache_key(video_id, frame_ids)

    attrs = %{
      cache_key: cache_key,
      video_id: video_id,
      frame_ids: frame_ids,
      gif_data: gif_data,
      file_size: opts[:file_size] || byte_size(gif_data),
      duration_ms: opts[:duration_ms],
      frame_count: opts[:frame_count] || length(frame_ids),
      accessed_at: DateTime.utc_now(),
      access_count: 1
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :cache_key)
  end

  @doc """
  Updates access tracking for a cached GIF.
  """
  def update_access_tracking(gif_cache) do
    gif_cache
    |> changeset(%{
      accessed_at: DateTime.utc_now(),
      access_count: gif_cache.access_count + 1
    })
    |> Repo.update()
  end

  @doc """
  Cleans up old cache entries.

  Removes entries that haven't been accessed in the specified number of days.
  """
  def cleanup_old_cache(days_old \\ 30) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_old, :day)

    from(gc in __MODULE__,
      where: gc.accessed_at < ^cutoff_date
    )
    |> Repo.delete_all()
  end

  @doc """
  Gets cache statistics.
  """
  def get_cache_stats do
    total_entries = Repo.aggregate(__MODULE__, :count, :id)
    total_size = Repo.aggregate(__MODULE__, :sum, :file_size) || 0

    most_accessed =
      from(gc in __MODULE__,
        order_by: [desc: gc.access_count],
        limit: 10,
        preload: :video
      )
      |> Repo.all()

    %{
      total_entries: total_entries,
      total_size_bytes: total_size,
      total_size_mb: Float.round(total_size / 1_048_576, 2),
      most_accessed: most_accessed
    }
  end
end
