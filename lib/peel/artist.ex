defmodule Peel.Artist do
  use    Peel.Model

  alias  Peel.Album
  alias  Peel.AlbumArtist
  alias  Peel.Artist
  alias  Peel.Repo
  alias  Peel.Track

  import Peel.String, only: [normalize_performer: 1]

  schema "artists" do
    field :name, :string

    field :normalized_name, :string

    has_many :album_artists, AlbumArtist
    has_many :tracks, Track
  end

  def sorted do
    Artist
    |> order_by(asc: :normalized_name)
    |> Repo.all
  end

  def for_track(%Track{performer: nil} = track) do
    %Track{ track | performer: "Unknown artist" } |> for_track
  end
  def for_track(%Track{performer: performer} = track) do
    normalized_performer = normalize_performer(performer)
    Artist
    |> where(normalized_name: ^normalized_performer)
    |> limit(1)
    |> Repo.one
    |> return_or_create(track)
    |> associate(track)
  end

  def return_or_create(nil, track) do
    %Artist{ name: track.performer }
    |> normalize
    |> Repo.insert!
  end
  def return_or_create(artist, _track) do
    artist
  end

  defp normalize(artist) do
    %Artist{ artist | normalized_name: normalize_performer(artist.name) }
  end

  def associate(artist, track) do
    %Track{ track | artist: artist, artist_id: artist.id }
  end

  def albums(for_artist) do
    from(artist in Artist,
      join: aa in AlbumArtist, on: artist.id == aa.artist_id,
      inner_join: album in Album, on: album.id == aa.album_id,
      select: album,
      where: artist.id == ^for_artist.id
    ) |> Repo.all
  end

  def renormalize do
    Repo.transaction fn ->
      Enum.each(all(), fn(a) ->
        a |> Ecto.Changeset.change(normalized_name: normalize_performer(a.name)) |> Repo.update!
      end)
    end
  end
end

