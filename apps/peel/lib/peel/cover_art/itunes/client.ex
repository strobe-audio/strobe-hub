defmodule Peel.CoverArt.ITunes.Client do
  @moduledoc """
  Search for album & artist metadata using the iTunes affiliate API documented
  here:

  https://affiliate.itunes.apple.com/resources/documentation/itunes-store-web-service-search-api/
  """

  use GenServer

  alias Peel.CoverArt.ITunes.Artist
  alias Peel.CoverArt.ITunes.Album

  require Logger

  @api_uri URI.parse "https://itunes.apple.com"
  # Limit to 2 requests per second
  @period 500

  @doc false
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def search_artist(name) do
    normalized_name = Peel.String.normalize(name)
    params = %{
      term: normalized_name,
      media: "music",
      entity: "musicArtist",
      limit: 4,
    }
    case request("/search", params) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        response = Poison.decode!(body, as: %{"results" => [Peel.CoverArt.ITunes.Artist]})
        {:ok, response["results"]}
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, :invalid_request}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def search_album(title) do
    normalized_title = Peel.String.normalize(title)
    params = %{
      term: normalized_title,
      media: "music",
      entity: "album",
      attribute: "albumTerm",
      limit: 4,
    }
    case request("/search", params) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        response = Poison.decode!(body, as: %{"results" => [Peel.CoverArt.ITunes.Album]})
        {:ok, response["results"]}
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, :invalid_request}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def artist_albums(artists) when is_list(artists) do
    albums =
      Enum.map(artists, fn(artist) ->
        {:ok, albums} = artist_albums(artist)
        albums
      end)
    {:ok, albums}
  end
  def artist_albums(%Artist{artistId: id}) do
    artist_albums(id)
  end
  def artist_albums(id) do
    params = %{
      id: id,
      entity: "album",
    }
    case request("/lookup", params) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        response =
        albums =
          Poison.decode!(body)
          |> Map.get("results", [])
          |> Enum.filter(fn(%{"wrapperType" => type}) -> type == "collection" end)
          |> Enum.map(&to_album/1)
        {:ok, albums}
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, :invalid_request}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp to_album(data) do
    Album
    |> Map.from_struct
    |> Enum.into(%{}, fn({key, default}) ->
      {key, Map.get(data, Atom.to_string(key), default)}
    end)
    |> Map.put(:__struct__, Album)
  end

  ##### Callbacks

  def init(_opts) do
    # TODO: perhaps make iTunes country a config setting, with an initial value
    # derived from ipinfo
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!("https://ipinfo.io", [{"accept", "application/json"}], [follow_redirect: true])
    location = body |> Poison.decode!
    Logger.info "Using iTunes search with country set to #{location["country"]}"

    {:ok, {location["country"], 0}}
  end

  def handle_call({:get, path, params}, _from, {country, last_call}) do
    uri = request_uri(path, geolocated_params(params, country))
    gap = now() - last_call
    if gap < @period  do
      IO.inspect [:sleeping, @period - gap]
      Process.sleep(@period - gap)
    end
    resp = uri |> URI.to_string |> HTTPoison.get([], [follow_redirect: true])
    {:reply, resp, {country, now()}}
  end

  defp geolocated_params(params, country) do
    Map.put(params, :country, country)
  end

  defp now do
    DateTime.utc_now() |> DateTime.to_unix(:milliseconds)
  end

  defp request(path, params) do
    GenServer.call(__MODULE__, {:get, path, params}, :infinity)
  end

  defp request_uri(path, params) do
    query = URI.encode_query(params)
    uri = @api_uri |> URI.merge(path)
    %URI{ uri | query: query }
  end
end
