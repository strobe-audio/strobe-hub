defmodule Peel.CoverArt.ITunes do
  defmodule Artist do
    @derive [Poison.Encoder]
    defstruct [
      :amgArtistId,
      :artistId,
      :artistLinkUrl,
      :artistName,
      :artistType,
      :primaryGenreId,
      :primaryGenreName,
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
      :artistName,
    ]

    alias __MODULE__, as: A

    @size_regex ~r{\d+x\d+(.*)\.([a-z]+)$}

    def cover_art(%A{artworkUrl60: url}, w, h) do
      uri = %URI{path: path60} = URI.parse(url)
      [name | path] = path60 |> Path.split |> Enum.reverse

      sized =
        case Regex.run(@size_regex, name, capture: :all_but_first) do
          [params, format] -> "#{w}x#{h}#{params}.#{format}"
          nil -> name
        end

      sized_path = [sized | path] |> Enum.reverse |> Path.join
      %URI{ uri | path: sized_path } |> URI.to_string
    end
  end

  alias Peel.CoverArt.ITunes.Client

  def cover_art(%Peel.Album{} = album, path) do
    album |> lookup_album_by_artist() |> IO.inspect |> lookup_album_by_title(album) |> IO.inspect |> download_cover_art(path)
  end

  def lookup_album_by_artist(%Peel.Album{title: title} = collection_album) do
    case Peel.Album.artists(collection_album) |> IO.inspect do
      [artist] ->
        {:ok, artists} = Client.search_artist(artist.name)
        albums =
          artists
          |> Enum.map(&Client.artist_albums/1)
          |> Enum.filter_map(&only_ok/1, &unwrap_ok/1)

        matches =
          albums
          |> Enum.map(&match_album(&1, collection_album))
          |> Enum.filter_map(&only_ok/1, &unwrap_ok/1)

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
      |> Enum.filter(fn(%Album{collectionName: name}) -> Peel.String.normalize(name) == title end)
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
      err -> err
    end
  end

  def download_cover_art({:error, _} = not_found, _path) do
    not_found
  end
  def download_cover_art({:ok, %Album{} = album}, path) do
    url = Album.cover_art(album, 500, 500) |> IO.inspect
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
end
