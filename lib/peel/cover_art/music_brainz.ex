defmodule MusicBrainz do
  alias Peel.Album
  alias MusicBrainz.Client

  defmodule Release do
    defstruct [:id, :title]
  end

  def cover_art(%Album{} = album, path) do
    album |> lookup_album_strict() |> lookup_album_loose(album) |> download_cover_art(path)
  end

  def lookup_album_strict(%Album{} = album) do
    artists = Peel.Album.artists(album)
    releases = Client.search_release(release: album.title, artist: Enum.map(artists, fn(a) -> a.name end))
    releases |> Stream.map(&lookup_cover_art/1) |> Enum.find({:error, :lookup_failed}, fn
      {:error, _} -> false
      {:ok, _} -> true
    end)
  end

  def lookup_album_loose({:ok, url}, _album) do
    {:ok, url}
  end
  def lookup_album_loose({:error, _reason}, %Album{} = album) do
    artists = Peel.Album.artists(album)
    releases = Client.search_release(release: album.title)
    releases |> Stream.map(&lookup_cover_art/1) |> Enum.find({:error, :lookup_failed}, fn
      {:error, _} -> false
      {:ok, _} -> true
    end)
  end


  def lookup_cover_art({:error, reason}) do
    {:error, reason}
  end
  def lookup_cover_art(%Release{} = release) do
    Client.release_cover_art(release)
    |> Enum.filter(&front_image/1)
    |> List.first
    |> image_url()
  end

  def download_cover_art({:error, reason}, _path) do
    {:error, reason}
  end
  def download_cover_art({:ok, url}, path) do
    HTTPoison.get(url, [], [follow_redirect: true]) |> save_cover_art(path)
  end

  def save_cover_art({:ok, %HTTPoison.Response{status_code: 200, body: body}}, path) do
    File.write(path, body)
  end
  def save_cover_art({:ok, %HTTPoison.Response{status_code: status_code}}, _path) do
    {:error, status_code}
  end
  def save_cover_art({:error, reason}, _path) do
    {:error, reason}
  end

  def image_url(nil) do
    {:error, :no_image_found}
  end

  def image_url(%{"image" => url}) do
    {:ok, url}
  end

  def front_image(%{"approved" => true, "front" => true}) do
    true
  end
  def front_image(_image) do
    false
  end
end
