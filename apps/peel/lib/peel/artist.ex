defmodule Peel.Artist do
  use    Peel.Model

  alias  Peel.Repo
  alias  Peel.Artist
  alias  Peel.Album

  schema "artists" do
    # Musical info
    field :name, :string

    has_many   :albums, Peel.Album
  end

  def for_album(%Album{performer: nil} = album) do
    %Album{ album | performer: "Unknown artist" } |> for_album
  end
  def for_album(%Album{performer: performer} = album) do
    Artist
    |> where(name: ^performer)
    |> limit(1)
    |> Repo.one
    |> return_or_create(album)
    |> associate(album)
  end

  def return_or_create(nil, album) do
    %Artist{ name: album.performer } |> Repo.insert!
  end
  def return_or_create(artist, _album) do
    artist
  end

  def associate(artist, album) do
    %Album{album | artist: artist, artist_id: artist.id}
  end
end

