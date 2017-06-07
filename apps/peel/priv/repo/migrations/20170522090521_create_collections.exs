defmodule Peel.Repo.Migrations.CreateCollections do
  use Ecto.Migration

  def change do
    create table(:collections, primary_key: false) do
      add :id,       :uuid,    primary_key: true
      add :name,     :string
      add :path,     :string
      add :track_count, :integer, default: 0
      add :album_count, :integer, default: 0
      add :artist_count, :integer, default: 0
      add :total_duration, :integer, default: 0
    end

    # Probably won't be needed but you never know
    create index(:collections, [:name])

    alter table(:albums) do
      add :collection_id, :uuid
    end
    create index(:albums, [:collection_id])

    alter table(:artists) do
      add :collection_id, :uuid
    end
    create index(:artists, [:collection_id])

    alter table(:tracks) do
      add :collection_id, :uuid
    end
    create index(:tracks, [:collection_id])

    alter table(:genres) do
      add :collection_id, :uuid
    end
    create index(:genres, [:collection_id])

    # make sure db has new table & columns
    flush()

    config = Application.get_env(:peel, Peel.Collection)
    root = Keyword.fetch!(config, :root)
    File.mkdir_p(root)

    collection = Peel.Collection.create("My Music", root)
    collection |> Peel.Collection.root |> File.mkdir_p()

    Peel.Repo.update_all(Peel.Album, set: [collection_id: collection.id])
    Peel.Repo.update_all(Peel.Artist, set: [collection_id: collection.id])
    Peel.Repo.update_all(Peel.Track, set: [collection_id: collection.id])
    # At this point the genres table has not been used at all
  end
end
