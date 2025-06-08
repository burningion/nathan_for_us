defmodule NathanForUs.Video.FrameCaption do
  @moduledoc """
  Ecto schema for frame-caption associations.
  Links video frames to their corresponding captions based on timestamp overlap.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NathanForUs.Video.{VideoFrame, VideoCaption}

  schema "frame_captions" do
    belongs_to :frame, VideoFrame
    belongs_to :caption, VideoCaption

    timestamps()
  end

  @required_fields [:frame_id, :caption_id]

  def changeset(frame_caption, attrs) do
    frame_caption
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:frame_id)
    |> foreign_key_constraint(:caption_id)
    |> unique_constraint(:frame_id, name: :frame_captions_frame_id_caption_id_index)
  end
end