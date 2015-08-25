defmodule Peel.Repo.Migrations.CreateBasicStructure do
  use Ecto.Migration

  def change do
    create table(:artists, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :normalized_name, :string
    end

    create index(:artists, [:name])
    create index(:artists, [:normalized_name])

    create table(:albums, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string
      add :normalized_title, :string
      add :date, :string
      add :genre, :string
      add :performer, :string
      add :disk_number, :integer
      add :disk_total, :integer
      add :track_total, :integer

      add :cover_image, :string
    end

    create index(:albums, [:normalized_title])
    create index(:albums, [:cover_image])

    create table(:album_artists) do
      add :artist_id, :uuid #references(:artists, type: :uuid)
      add :album_id,  :uuid #references(:albums, type: :uuid)
    end

    create index(:album_artists, [:artist_id])
    create index(:album_artists, [:album_id])

    create table(:tracks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string
      add :normalized_title, :string
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

      add :cover_image, :string

      add :album_id, references(:albums, type: :uuid)
      add :artist_id, references(:artists, type: :uuid)
    end

    create index(:tracks, [:path])
    create index(:tracks, [:normalized_title])

    create table(:genres, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :normalized_name, :string
    end

    create index(:genres, [:normalized_name])

    create table(:track_genres) do
      add :track_id, references(:tracks, type: :uuid)
      add :genre_id, references(:genres, type: :uuid)
    end

    create index(:track_genres, [:track_id])
    create index(:track_genres, [:genre_id])
  end
end
