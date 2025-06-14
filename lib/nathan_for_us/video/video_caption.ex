defmodule NathanForUs.Video.VideoCaption do
  @moduledoc """
  Ecto schema for video caption records.
  Represents subtitle/caption text with timing information.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NathanForUs.Video.{Video, VideoFrame, FrameCaption}

  schema "video_captions" do
    field :start_time_ms, :integer
    field :end_time_ms, :integer
    field :text, :string
    field :caption_index, :integer

    belongs_to :video, Video
    many_to_many :frames, VideoFrame, join_through: FrameCaption

    timestamps()
  end

  @required_fields [:video_id, :start_time_ms, :end_time_ms, :text]
  @optional_fields [:caption_index]

  def changeset(caption, attrs) do
    caption
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:start_time_ms, greater_than_or_equal_to: 0)
    |> validate_number(:end_time_ms, greater_than_or_equal_to: 0)
    |> validate_number(:caption_index, greater_than_or_equal_to: 0)
    |> validate_time_range()
    |> foreign_key_constraint(:video_id)
  end

  defp validate_time_range(changeset) do
    start_time = get_field(changeset, :start_time_ms)
    end_time = get_field(changeset, :end_time_ms)

    if start_time && end_time && start_time >= end_time do
      add_error(changeset, :end_time_ms, "must be greater than start time")
    else
      changeset
    end
  end
end
