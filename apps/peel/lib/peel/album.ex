defmodule Peel.Album do
  use    Peel.Model

  alias  Peel.Repo
  alias  Peel.Track
  alias  Peel.Artist
  alias  Peel.Album
  alias  Peel.AlbumArtist

  @derive {Poison.Encoder, only: [:id, :title, :performer, :date, :genre, :disk_number, :disk_total, :track_total, :artist_id]}

  schema "albums" do
    # Musical info
    field :title, :string
    field :performer, :string
    field :date, :string
    field :genre, :string

    field :disk_number, :integer
    field :disk_total, :integer
    field :track_total, :integer

    field :normalized_title, :string

    has_many :album_artists, Peel.AlbumArtist
    has_many :tracks, Peel.Track
  end

  def by_title(title) do
    Album
    |> where(title: ^title)
    |> limit(1)
    |> Repo.one
  end

  def for_track(%Track{disk_number: nil} = track) do
    %Track{track | disk_number: 1} |> for_track
  end
  def for_track(%Track{album_title: title} = track) do
    normalized_title = Peel.String.normalize(title)
    Album
    |> where(normalized_title: ^normalized_title)
    |> limit(1)
    |> Repo.one
    |> return_or_create(track)
    |> associate(track)
  end

  def return_or_create(nil, track) do
    %Album{
      title: track.album_title,
      performer: track.performer,
      date: track.date,
      genre: track.genre,
      disk_number: track.disk_number,
      disk_total: track.disk_total,
      track_total: track.track_total,
    }
    |> normalize
    |> Repo.insert!
  end
  def return_or_create(album, _track) do
    album
  end

  defp normalize(album) do
    %Album{ album | normalized_title: Peel.String.normalize(album.title) }
  end

  def associate(album, track) do
    %Track{ track | album: album, album_id: album.id }
  end

  def tracks(album) do
    album = album |> Repo.preload(:tracks)
    album.tracks
  end

  def artists(album) do
    from(a in Album,
      join: aa in AlbumArtist, on: a.id == aa.album_id,
      inner_join: ar in Artist, on: ar.id == aa.artist_id,
      select: ar,
      where: a.id == ^album.id
    ) |> Repo.all
  end
end
