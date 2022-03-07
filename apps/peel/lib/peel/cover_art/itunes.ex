defmodule Peel.CoverArt.ITunes do
  defmodule ImageURL do
    @size_regex ~r{\d+x\d+(.*)\.([a-z]+)$}

    def with_size(url, w, h) do
      uri = %URI{path: orig_path} = URI.parse(url)
      [name | path] = orig_path |> Path.split() |> Enum.reverse()

      sized =
        case Regex.run(@size_regex, name, capture: :all_but_first) do
          [params, format] -> "#{w}x#{h}#{params}.#{format}"
          nil -> name
        end

      sized_path = [sized | path] |> Enum.reverse() |> Path.join()
      %URI{uri | path: sized_path} |> URI.to_string()
    end
  end

  defmodule Artist do
    @derive [Poison.Encoder]
    defstruct [
      :amgArtistId,
      :artistId,
      :artistLinkUrl,
      :artistName,
      :artistType,
      :primaryGenreId,
      :primaryGenreName
    ]
  end

  defmodule Album do
    @derive [Poison.Encoder]
    defstruct [
      :collectionId,
      :collectionName,
      :collectionViewUrl,
      :artworkUrl60,
      :artworkUrl100,
      :trackCount,
      :artistName
    ]

    alias __MODULE__, as: A

    def cover_art(%A{artworkUrl60: url}, w, h) do
      Peel.CoverArt.ITunes.ImageURL.with_size(url, w, h)
    end
  end

  alias Peel.CoverArt.ITunes.Client

  def artist_image(%Peel.Artist{} = artist, path) do
    # TODO: verify match by searching for result who has an album matching ours
    with {:ok, [match | _]} <- Client.search_artist(artist.name),
         {:ok, image} <- Client.artist_image(match),
         sized_image <- Peel.CoverArt.ITunes.ImageURL.with_size(image, 500, 500) do
      http_get(sized_image) |> save_cover_art(path)
    else
      {:error, _reason} = err -> err
      err -> {:error, err}
    end
  end

  defp http_get(url, headers \\ []) do
    Finch.build(:get, url, headers)
    |> Finch.request(Peel.Finch)
  end

  def cover_art(%Peel.Album{} = album, path) do
    album |> lookup_album_by_artist() |> lookup_album_by_title(album) |> download_cover_art(path)
  end

  def lookup_album_by_artist(%Peel.Album{} = collection_album) do
    case Peel.Album.artists(collection_album) do
      [artist] ->
        {:ok, artists} = Client.search_artist(artist.name)

        albums =
          artists
          |> Stream.map(&Client.artist_albums/1)
          |> Stream.filter(&only_ok/1)
          |> Enum.map(&unwrap_ok/1)

        matches =
          albums
          |> Stream.map(&match_album(&1, collection_album))
          |> Stream.filter(&only_ok/1)
          |> Enum.map(&unwrap_ok/1)

        case matches do
          [] -> {:error, :no_match}
          [album | _] -> {:ok, album}
        end

      _ ->
        {:error, :multitple_artists}
    end
  end

  def only_ok({:ok, _}), do: true
  def only_ok(_), do: false

  defp unwrap_ok({:ok, v}), do: v

  def match_album(albums, %Peel.Album{normalized_title: title} = _album) do
    matches =
      albums
      |> Enum.filter(fn %Album{collectionName: name} -> Peel.String.normalize(name) == title end)

    case matches do
      [] ->
        {:error, :not_found}

      [album | _] ->
        {:ok, album}
    end
  end

  def lookup_album_by_title({:ok, _} = found, _album) do
    found
  end

  def lookup_album_by_title(_not_found, %Peel.Album{} = album) do
    case Client.search_album(album.title) do
      {:ok, [match | _]} ->
        {:ok, match}

      {:ok, []} ->
        {:error, :no_match}

      err ->
        err
    end
  end

  def download_cover_art({:error, _} = not_found, _path) do
    not_found
  end

  def download_cover_art({:ok, %Album{} = album}, path) do
    url = Album.cover_art(album, 500, 500)
    http_get(url) |> save_cover_art(path)
  end

  def save_cover_art({:ok, %Finch.Response{status: 200, body: body}}, path) do
    File.write(path, body)
  end

  def save_cover_art({:ok, %Finch.Response{status: status}}, _path) do
    {:error, status}
  end

  def save_cover_art({:error, reason}, _path) do
    {:error, reason}
  end
end
