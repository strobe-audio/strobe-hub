defmodule Peel.Artist do
  use    Peel.Model

  alias  __MODULE__
  alias  Peel.{Album, AlbumArtist, Collection, Repo, Track}

  import Peel.String, only: [normalize_performer: 1]

  schema "artists" do
    field :name, :string

    field :normalized_name, :string
    field :image, :string

    field :itunes_url, :string
    field :itunes_id, :integer

    belongs_to :collection, Peel.Collection, type: Ecto.UUID
    has_many :album_artists, AlbumArtist, on_delete: :delete_all
    has_many :tracks, Track
  end

  def sorted(%Collection{id: collection_id}) do
    Artist
    |> where(collection_id: ^collection_id)
    |> order_by(asc: :normalized_name)
    |> Repo.all
  end

  def for_track(%Track{performer: nil} = track) do
    %Track{track | performer: "Unknown artist"} |> for_track
  end
  def for_track(%Track{performer: performer, collection_id: collection_id} = track) do
    normalized_performer = normalize_performer(performer)
    Artist
    |> where(collection_id: ^collection_id, normalized_name: ^normalized_performer)
    |> limit(1)
    |> Repo.one
    |> return_or_create(track)
    |> associate(track)
  end

  def return_or_create(nil, track) do
    %Artist{name: track.performer, collection_id: track.collection_id}
    |> normalize
    |> Repo.insert!
  end
  def return_or_create(artist, _track) do
    artist
  end

  defp normalize(artist) do
    %Artist{artist | normalized_name: normalize_performer(artist.name)}
  end

  def associate(artist, track) do
    %Track{track | artist: artist, artist_id: artist.id}
  end

  def albums(for_artist) do
    from(artist in Artist,
      join: aa in AlbumArtist, on: artist.id == aa.artist_id,
      inner_join: album in Album, on: album.id == aa.album_id,
      select: album,
      where: artist.id == ^for_artist.id,
      order_by: [desc: album.date]
    ) |> Repo.all
  end

  def tracks(artist) do
    artist = artist |> Repo.preload(:tracks)
    artist.tracks
  end

  def renormalize do
    Repo.transaction fn ->
      Enum.each(all(), fn(a) ->
        a |> Ecto.Changeset.change(normalized_name: normalize_performer(a.name)) |> Repo.update!
      end)
    end
  end

  def search(query, %Collection{id: collection_id}) do
    pattern = "%#{Peel.String.normalize(query)}%"
    from(artist in Artist, where: like(artist.normalized_name, ^pattern)) |> where(collection_id: ^collection_id) |> Repo.all
  end

  def without_image do
    from(a in Artist,
      where: (is_nil(a.image) or (a.image == ""))
    ) |> Repo.all
  end

  def change(model, changes) do
    Ecto.Changeset.change(model, changes)
  end

  def set_image(artist, image_path) do
    Artist.change(artist, %{image: image_path}) |> Repo.update!
  end
end

