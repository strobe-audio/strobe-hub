defmodule Peel.Album do
  use Peel.Model

  alias __MODULE__
  alias Peel.{Repo, Collection, Track, Artist, AlbumArtist}

  @derive {Poison.Encoder,
           only: [
             :id,
             :title,
             :performer,
             :date,
             :genre,
             :disk_number,
             :disk_total,
             :track_total,
             :artist_id
           ]}

  schema "albums" do
    # Musical info
    field(:title, :string)
    field(:performer, :string)
    field(:date, :string)
    field(:genre, :string)

    field(:disk_number, :integer)
    field(:disk_total, :integer)
    field(:track_total, :integer)

    field(:normalized_title, :string)

    field(:cover_image, :string)

    belongs_to(:collection, Peel.Collection, type: Ecto.UUID)
    has_many(:album_artists, Peel.AlbumArtist, on_delete: :delete_all)
    has_many(:tracks, Peel.Track)
  end

  def sorted(%Collection{id: collection_id}) do
    Album
    |> where(collection_id: ^collection_id)
    |> order_by(asc: :normalized_title)
    |> Repo.all()
  end

  def by_title(title, %Collection{id: collection_id}) do
    normalized_title = Peel.String.normalize(title)

    Album
    |> where(collection_id: ^collection_id, normalized_title: ^normalized_title)
    |> limit(1)
    |> Repo.one()
  end

  def without_cover_image do
    from(a in Album,
      where: is_nil(a.cover_image) or a.cover_image == ""
    )
    |> Repo.all()
  end

  def set_cover_image(album, image_path) do
    album = Album.change(album, %{cover_image: image_path}) |> Repo.update!()

    from(t in Peel.Track,
      where: t.album_id == ^album.id and is_nil(t.cover_image)
    )
    |> Repo.update_all(set: [cover_image: image_path])

    album
  end

  def for_track(%Track{disk_number: nil} = track) do
    %Track{track | disk_number: 1} |> for_track
  end

  def for_track(%Track{album_title: title, collection_id: collection_id} = track) do
    normalized_title = Peel.String.normalize(title)

    Album
    |> where(normalized_title: ^normalized_title, collection_id: ^collection_id)
    |> limit(1)
    |> Repo.one()
    |> return_or_create(track)
    |> associate(track)
  end

  def return_or_create(nil, track) do
    %Album{
      collection_id: track.collection_id,
      title: track.album_title,
      performer: track.performer,
      date: track.date,
      genre: track.genre,
      disk_number: track.disk_number,
      disk_total: track.disk_total,
      track_total: track.track_total
    }
    |> normalize
    |> Repo.insert!()
  end

  def return_or_create(album, _track) do
    album
  end

  defp normalize(album) do
    %Album{album | normalized_title: Peel.String.normalize(album.title)}
  end

  def associate(album, track) do
    %Track{track | album: album, album_id: album.id, cover_image: album.cover_image}
  end

  def tracks(album) do
    album = album |> Repo.preload(tracks: from(t in Peel.Track, order_by: t.track_number))
    album.tracks
  end

  def artists(album) do
    from(a in Album,
      join: aa in AlbumArtist,
      on: a.id == aa.album_id,
      inner_join: ar in Artist,
      on: ar.id == aa.artist_id,
      select: ar,
      where: a.id == ^album.id,
      order_by: ar.normalized_name
    )
    |> Repo.all()
  end

  def change(model, changes) do
    Ecto.Changeset.change(model, changes)
  end

  def search(query, %Collection{id: collection_id}) do
    pattern = "%#{Peel.String.normalize(query)}%"

    (album in Album)
    |> from(where: like(album.normalized_title, ^pattern))
    |> where(collection_id: ^collection_id)
    |> Repo.all()
  end
end
