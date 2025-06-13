defmodule NathanForUs.Video.Video do
  @moduledoc """
  Ecto schema for video records.
  Represents a video file that has been or will be processed for frame extraction.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NathanForUs.Video.{VideoFrame, VideoCaption}
  alias NathanForUs.Gif

  schema "videos" do
    field :title, :string
    field :file_path, :string
    field :duration_ms, :integer
    field :fps, :float
    field :frame_count, :integer
    field :status, :string, default: "pending"
    field :processed_at, :utc_datetime
    field :metadata, :map

    has_many :frames, VideoFrame, foreign_key: :video_id
    has_many :captions, VideoCaption, foreign_key: :video_id
    has_many :gifs, Gif, foreign_key: :video_id

    timestamps()
  end

  @required_fields [:title, :file_path]
  @optional_fields [:duration_ms, :fps, :frame_count, :status, :processed_at, :metadata]
  @valid_statuses ["pending", "processing", "completed", "failed"]

  def changeset(video, attrs) do
    video
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:duration_ms, greater_than: 0)
    |> validate_number(:fps, greater_than: 0)
    |> validate_number(:frame_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:file_path)
    |> validate_file_path()
  end

  defp validate_file_path(changeset) do
    case get_field(changeset, :file_path) do
      nil -> changeset
      file_path ->
        if String.ends_with?(file_path, [".mp4", ".mov", ".avi", ".mkv", ".webm"]) do
          changeset
        else
          add_error(changeset, :file_path, "must be a valid video file format")
        end
    end
  end
end