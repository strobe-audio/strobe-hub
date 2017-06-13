defmodule Peel.Repo.Migrations.AddImageToArtists do
  use Ecto.Migration

  def change do
    alter table(:artists) do
      add :image, :string
      add :itunes_url, :string
      add :itunes_id, :integer
    end
  end
end
