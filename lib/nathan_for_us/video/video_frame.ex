defmodule NathanForUs.Video.VideoFrame do
  @moduledoc """
  Ecto schema for video frame records.
  Represents individual frames extracted from a video file.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NathanForUs.Video.{Video, VideoCaption, FrameCaption}

  schema "video_frames" do
    field :frame_number, :integer
    field :timestamp_ms, :integer
    field :file_path, :string
    field :file_size, :integer
    field :width, :integer
    field :height, :integer
    field :image_data, :binary
    field :compression_ratio, :float

    belongs_to :video, Video
    many_to_many :captions, VideoCaption, join_through: FrameCaption

    timestamps()
  end

  @required_fields [:video_id, :frame_number, :timestamp_ms]
  @optional_fields [:file_path, :file_size, :width, :height, :image_data, :compression_ratio]

  def changeset(frame, attrs) do
    frame
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:frame_number, greater_than_or_equal_to: 0)
    |> validate_number(:timestamp_ms, greater_than_or_equal_to: 0)
    |> validate_number(:file_size, greater_than: 0)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> foreign_key_constraint(:video_id)
    |> unique_constraint(:video_id, name: :video_frames_video_id_frame_number_index)
  end
end