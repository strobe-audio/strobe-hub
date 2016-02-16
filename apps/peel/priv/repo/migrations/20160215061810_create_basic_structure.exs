defmodule Peel.Repo.Migrations.CreateBasicStructure do
  use Ecto.Migration

  def change do
    create table(:artists) do
      add :name, :string
    end
    create index(:artists, [:name])

    create table(:albums) do
      add :title, :string
      add :date, :string
      add :genre, :string
      add :performer, :string
      add :disk_number, :integer
      add :disk_total, :integer
      add :track_total, :integer

      add :artist_id, references(:artists)
    end
    create index(:albums, [:title, :disk_number])

    create table(:tracks) do
      add :title, :string
      add :album_title, :string
      add :composer, :string
      add :date, :string
      add :genre, :string
      add :performer, :string
      add :disk_number, :integer
      add :disk_total, :integer
      add :track_number, :integer
      add :track_total, :integer

      add :path, :string
      add :mtime, :datetime

      add :album_id, references(:albums)
    end
    create index(:tracks, [:path])
  end
end
