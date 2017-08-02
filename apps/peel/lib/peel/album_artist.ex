defmodule Peel.AlbumArtist do
  import Ecto.Query
  use    Ecto.Schema

  alias  __MODULE__
  alias  Peel.{Repo, Track}

  schema "album_artists" do
    belongs_to :artist, Peel.Artist, type: Ecto.UUID
    belongs_to :album, Peel.Album, type: Ecto.UUID
  end

  def all do
    AlbumArtist |> Repo.all
  end

  def for_track(%Track{album_id: album_id, artist_id: artist_id} = track) do
    AlbumArtist
    |> where(artist_id: ^artist_id, album_id: ^album_id)
    |> limit(1)
    |> Repo.one
    |> return_or_create(artist_id, album_id)
    |> associate(track)
  end

  def return_or_create(nil, artist_id, album_id) do
    %Peel.AlbumArtist{artist_id: artist_id, album_id: album_id} |> Repo.insert!
  end
  def return_or_create(album_artist, _artist_id, _album_id) do
    album_artist
  end

  def associate(_album_artist, track) do
    track
  end
end
