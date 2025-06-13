defmodule NathanForUs.Viral.ViralGif do
  use Ecto.Schema
  import Ecto.Changeset

  schema "viral_gifs" do
    field :title, :string
    field :description, :string
    field :start_frame_index, :integer
    field :end_frame_index, :integer
    field :view_count, :integer, default: 0
    field :share_count, :integer, default: 0
    field :is_featured, :boolean, default: false
    field :category, :string
    field :frame_data, :string # JSON encoded frame data

    belongs_to :video, NathanForUs.Video.Video
    belongs_to :created_by_user, NathanForUs.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(viral_gif, attrs) do
    viral_gif
    |> cast(attrs, [:title, :description, :start_frame_index, :end_frame_index, 
                    :video_id, :created_by_user_id, :is_featured, :category, :frame_data])
    |> validate_required([:start_frame_index, :end_frame_index, :video_id, :created_by_user_id])
    |> validate_number(:start_frame_index, greater_than_or_equal_to: 0)
    |> validate_number(:end_frame_index, greater_than: 0)
    |> validate_frame_sequence()
    |> foreign_key_constraint(:video_id)
    |> foreign_key_constraint(:created_by_user_id)
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
  def generate_title(category) do
    case category do
      "awkward_silence" -> "The Awkward Pause"
      "business_genius" -> "Business Mastermind"
      "confused_stare" -> "Nathan's Confusion"
      "dramatic_pause" -> "Dramatic Nathan"
      "summit_ice" -> "Summit Ice Moment"
      "the_plan" -> "The Plan"
      "rehearsal_prep" -> "Rehearsal Time"
      "uncomfortable_truth" -> "Uncomfortable Truth"
      _ -> "Nathan Moment"
    end
  end
end