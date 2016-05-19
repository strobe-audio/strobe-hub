defmodule Peel.Artist do
  use    Peel.Model

  alias  Peel.Repo
  alias  Peel.Artist
  alias  Peel.Album

  schema "artists" do
    # Musical info
    field :name, :string

    field :normalized_name, :string

    has_many   :albums, Peel.Album
  end

  def for_album(%Album{performer: nil} = album) do
    %Album{ album | performer: "Unknown artist" } |> for_album
  end
  def for_album(%Album{performer: performer} = album) do
    normalized_performer = Peel.String.normalize(performer)
    Artist
    |> where(normalized_name: ^normalized_performer)
    |> limit(1)
    |> Repo.one
    |> return_or_create(album)
    |> associate(album)
  end

  def return_or_create(nil, album) do
    %Artist{ name: album.performer }
    |> normalize
    |> Repo.insert!
  end
  def return_or_create(artist, _album) do
    artist
  end

  defp normalize(artist) do
    %Artist{ artist | normalized_name: Peel.String.normalize(artist.name) }
  end

  def associate(artist, album) do
    %Album{album | artist: artist, artist_id: artist.id}
  end

  def albums(artist) do
    artist = artist |> Repo.preload(:albums)
    artist.albums
  end
end

