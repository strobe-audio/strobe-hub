defmodule Peel.CoverArt.ITunes.Client do
  @moduledoc """
  Search for album & artist metadata using the iTunes affiliate API documented
  here:

  https://affiliate.itunes.apple.com/resources/documentation/itunes-store-web-service-search-api/
  """

  use GenServer

  alias Peel.CoverArt.ITunes.{Album, Artist}

  require Logger

  @api_uri URI.parse("https://itunes.apple.com")
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
      limit: 4
    }

    case request_with_retries("/search", params, 5) do
      {:ok, body} ->
        response = Poison.decode!(body, as: %{"results" => [Peel.CoverArt.ITunes.Artist]})
        {:ok, response["results"]}

      err ->
        err
    end
  end

  def search_album(title) do
    normalized_title = Peel.String.normalize(title)

    params = %{
      term: normalized_title,
      media: "music",
      entity: "album",
      attribute: "albumTerm",
      limit: 4
    }

    case request_with_retries("/search", params, 5) do
      {:ok, body} ->
        response = Poison.decode!(body, as: %{"results" => [Peel.CoverArt.ITunes.Album]})
        {:ok, response["results"]}

      err ->
        err
    end
  end

  def artist_albums(artists) when is_list(artists) do
    albums =
      Enum.map(artists, fn artist ->
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
      entity: "album"
    }

    case request_with_retries("/lookup", params, 5) do
      {:ok, body} ->
        albums =
          Poison.decode!(body)
          |> Map.get("results", [])
          |> Enum.filter(fn %{"wrapperType" => type} -> type == "collection" end)
          |> Enum.map(&to_album/1)

        {:ok, albums}

      err ->
        err
    end
  end

  # TODO: add retries etc
  def artist_image(%Artist{artistLinkUrl: url}) do
    case HTTPoison.get(url, [], follow_redirect: true) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        extract_artist_image(body)

      {:ok, resp} ->
        Logger.error("Got error response from iTunes #{url} => #{inspect(resp)}")
        {:error, :invalid_request}

      {:error, %HTTPoison.Error{reason: reason} = resp} ->
        Logger.error("Got error response from iTunes #{url} => #{inspect(resp)}")
        {:error, reason}
    end
  end

  @image_meta_re ~r{<meta.*?property="og:image".*?>}
  @meta_url_re ~r{content="([^"]+)"}

  defp extract_artist_image(body) do
    with [meta] <- Regex.run(@image_meta_re, body),
         [_, url] <- Regex.run(@meta_url_re, meta) do
      {:ok, url}
    else
      _ ->
        {:error, :invalid_html}
    end
  end

  defp to_album(data) do
    Album
    |> Map.from_struct()
    |> Enum.into(%{}, fn {key, default} ->
      {key, Map.get(data, Atom.to_string(key), default)}
    end)
    |> Map.put(:__struct__, Album)
  end

  ##### Callbacks

  def init(_opts) do
    # TODO: perhaps make iTunes country a config setting, with an initial value
    # derived from ipinfo
    country =
      case HTTPoison.get("https://ipinfo.io", [{"accept", "application/json"}],
             follow_redirect: true
           ) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          location = body |> Poison.decode!()
          location["country"]

        {_, resp} ->
          Logger.warn("Unable to resolve iTunes country using IP: #{inspect(resp)}")
          "GB"
      end

    Logger.info("Using iTunes search with country set to #{country}")

    {:ok, {country, 0}}
  end

  def handle_call({:get, path, params}, _from, {country, last_call}) do
    uri = request_uri(path, geolocated_params(params, country))
    gap = now() - last_call

    if gap < @period do
      Process.sleep(@period - gap)
    end

    resp = uri |> URI.to_string() |> HTTPoison.get([], follow_redirect: true)
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
    %URI{uri | query: query}
  end

  defp request_with_retries(path, params, tries, last_resp \\ nil)

  defp request_with_retries(_path, _params, 0, last_resp) do
    case last_resp do
      %HTTPoison.Response{status_code: status} ->
        {:error, :"status_#{status}"}

      %HTTPoison.Error{reason: reason} ->
        {:error, reason}
    end
  end

  defp request_with_retries(path, params, tries, _last_resp) do
    case request(path, params) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {_, resp} ->
        Logger.warn(
          "Got bad response from server, #{path} -> #{inspect(resp)} retrying (#{tries - 1})"
        )

        Process.sleep(1_000)
        request_with_retries(path, params, tries - 1, resp)
    end
  end
end
