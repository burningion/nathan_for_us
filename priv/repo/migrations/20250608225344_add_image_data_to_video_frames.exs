defmodule NathanForUs.Repo.Migrations.AddImageDataToVideoFrames do
  use Ecto.Migration

  def change do
    alter table(:video_frames) do
      # Compressed JPEG binary data
      add :image_data, :binary
      # Track compression efficiency
      add :compression_ratio, :float
    end

    # Make file_path nullable since we'll store binary data instead
    alter table(:video_frames) do
      modify :file_path, :string, null: true
    end

    create index(:video_frames, [:image_data], where: "image_data IS NOT NULL")
  end
end
