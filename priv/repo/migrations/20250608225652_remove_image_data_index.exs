defmodule NathanForUs.Repo.Migrations.RemoveImageDataIndex do
  use Ecto.Migration

  def change do
    # Remove the problematic index on binary data
    drop_if_exists index(:video_frames, [:image_data])
  end
end
