defmodule Peel.Repo.Migrations.CreateBasicStructure do
  use Ecto.Migration

  def change do
    create table(:artists, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
    end
    create index(:artists, [:name])

    create table(:albums, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string
      add :date, :string
      add :genre, :string
      add :performer, :string
      add :disk_number, :integer
      add :disk_total, :integer
      add :track_total, :integer

      add :artist_id, references(:artists, type: :string)
    end
    create index(:albums, [:title, :disk_number])

    create table(:tracks, primary_key: false) do
      add :id, :uuid, primary_key: true
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

      add :duration_ms, :integer, default: 0
      add :mime_type, :string

      add :path, :string
      add :mtime, :datetime

      add :album_id, references(:albums, type: :string)
    end
    create index(:tracks, [:path])
  end
end
