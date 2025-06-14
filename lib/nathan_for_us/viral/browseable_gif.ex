defmodule NathanForUs.Viral.BrowseableGif do
  @moduledoc """
  Browseable GIFs are ALL generated GIFs that users can browse for inspiration.
  These are different from ViralGifs which are only the ones posted to the public timeline.

  Every time someone generates a GIF, it gets saved here for browsing,
  regardless of whether they post it to the timeline or not.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "browseable_gifs" do
    field :title, :string
    field :start_frame_index, :integer
    field :end_frame_index, :integer
    field :category, :string
    # JSON encoded frame data
    field :frame_data, :string
    # Could be made private in future
    field :is_public, :boolean, default: true
    field :upvotes_count, :integer, default: 0
    field :downvotes_count, :integer, default: 0
    field :hot_score, :float, default: 0.0
    field :hot_score_updated_at, :utc_datetime

    belongs_to :video, NathanForUs.Video.Video
    belongs_to :created_by_user, NathanForUs.Accounts.User
    # Link to the actual GIF binary data
    belongs_to :gif, NathanForUs.Gif
    has_many :gif_votes, NathanForUs.Viral.GifVote

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(browseable_gif, attrs) do
    browseable_gif
    |> cast(attrs, [
      :title,
      :start_frame_index,
      :end_frame_index,
      :video_id,
      :created_by_user_id,
      :gif_id,
      :category,
      :frame_data,
      :is_public,
      :upvotes_count,
      :downvotes_count,
      :hot_score,
      :hot_score_updated_at
    ])
    |> validate_required([:start_frame_index, :end_frame_index, :video_id, :gif_id])
    |> validate_number(:start_frame_index, greater_than_or_equal_to: 0)
    |> validate_number(:end_frame_index, greater_than: 0)
    |> validate_frame_sequence()
    |> foreign_key_constraint(:video_id)
    |> foreign_key_constraint(:created_by_user_id)
    |> foreign_key_constraint(:gif_id)
  end

  defp validate_frame_sequence(changeset) do
    start_frame = get_field(changeset, :start_frame_index)
    end_frame = get_field(changeset, :end_frame_index)

    if start_frame && end_frame && end_frame <= start_frame do
      add_error(changeset, :end_frame_index, "must be greater than start frame")
    else
      changeset
    end
  end

  @doc """
  Generates a title based on Nathan moment categories.
  """
  def generate_title(category, video_title) do
    base_title =
      case category do
        "awkward_silence" -> "Awkward Pause"
        "business_genius" -> "Business Genius"
        "confused_stare" -> "Nathan's Confusion"
        "dramatic_pause" -> "Dramatic Moment"
        "summit_ice" -> "Summit Ice"
        "the_plan" -> "The Plan"
        "rehearsal_prep" -> "Rehearsal"
        "uncomfortable_truth" -> "Uncomfortable Truth"
        _ -> "Nathan Moment"
      end

    "#{base_title} - #{video_title}"
  end
end
