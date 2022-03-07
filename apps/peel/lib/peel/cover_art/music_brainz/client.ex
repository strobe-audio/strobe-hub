defmodule MusicBrainz.Client do
  use GenServer

  @mb_uri URI.parse("http://musicbrainz.org")
  @ca_uri URI.parse("http://coverartarchive.org")

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, 0}
  end

  # API is limited to 1 request per second
  @period 1000

  # Rate limited api calls, max 1 per second
  def handle_call({:get, uri}, _from, last_call) do
    time = now() - last_call

    if time < @period do
      IO.inspect([:sleeping, @period - time])
      Process.sleep(@period - time)
    end

    resp = http_get(uri)
    {:reply, resp, now()}
  end

  defp http_get(url, headers \\ []) do
    Finch.build(:get, url, headers)
    |> Finch.request(Peel.Finch)
  end

  defp now do
    DateTime.utc_now() |> DateTime.to_unix(:milliseconds)
  end

  def search_release(query) do
    uri = search_url(:release, query)
    get!(uri) |> parse_release_search
  end

  def release_cover_art(%MusicBrainz.Release{id: id}) do
    uri = URI.merge(@ca_uri, "/release/#{id}") |> URI.to_string() |> IO.inspect()
    get!(uri) |> parse_cover_art_lookup
  end

  def get!(uri) do
    GenServer.call(__MODULE__, {:get, uri}, :infinity)
  end

  def parse_cover_art_lookup({:ok, %Finch.Response{status: 200, body: body}}) do
    response = Poison.decode!(body)
    response["images"]
  end

  def parse_cover_art_lookup({:ok, %Finch.Response{}}) do
    []
  end

  def parse_cover_art_lookup({:error, _}) do
    []
  end

  def parse_release_search({:ok, %Finch.Response{body: body}}) do
    Floki.find(body, "metadata > release-list > release") |> build_releases
  end

  def parse_release_search({:error, _reason}) do
    []
  end

  def build_releases(result) do
    build_releases(result, [])
  end

  def build_releases([], releases) do
    Enum.reverse(releases)
  end

  def build_releases([{"release", attrs, _children} | rest], releases) do
    id = get_attr(attrs, "id")
    release = %MusicBrainz.Release{id: id}
    build_releases(rest, [release | releases])
  end

  @doc ~S"""

      iex> MusicBrainz.Client.get_attr([{"id", "something"}, {"other", "not"}], "id")
      "something"

  """
  def get_attr(attrs, name) do
    attrs |> Enum.find(fn {k, _v} -> k == name end) |> elem(1)
  end

  @doc ~S"""

      iex> MusicBrainz.Client.search_url(:release)
      "http://musicbrainz.org/ws/2/release"
      iex> MusicBrainz.Client.search_url(:release, release: "Something Or")
      "http://musicbrainz.org/ws/2/release?query=release:Something%20Or"

  """
  def search_url(resource, query \\ []) do
    params = make_query(query)
    URI.merge(@mb_uri, "/ws/2/#{resource}#{params}") |> URI.to_string() |> IO.inspect()
  end

  @doc ~S"""

      iex> MusicBrainz.Client.make_query()
      ""
      iex> MusicBrainz.Client.make_query(release: "Something")
      "?query=release:Something"
      iex> MusicBrainz.Client.make_query(release: "Something", artist: "Famous")
      "?query=release:Something%20AND%20artist:Famous"
      iex> MusicBrainz.Client.make_query(release: "Something", artist: ["Famous", "Infamous", "Void"])
      "?query=release:Something%20AND%20(artist:Famous%20OR%20artist:Infamous%20OR%20artist:Void)"

  """
  def make_query do
    make_query([])
  end

  def make_query([]) do
    ""
  end

  def make_query(query) do
    make_query(query, [])
  end

  def make_query([], query) do
    params = query |> Enum.reverse() |> Enum.join(" AND ") |> URI.encode()
    "?query=#{params}"
  end

  def make_query([{field, value} | rest], query) do
    make_query(rest, [make_parameter(field, value) | query])
  end

  def make_parameter(field, value) when is_list(value) do
    matches = value |> Enum.map(&make_parameter(field, &1)) |> Enum.join(" OR ")
    "(#{matches})"
  end

  def make_parameter(field, value) do
    "#{field}:#{value}"
  end
end
