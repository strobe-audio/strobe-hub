defmodule Otis.Library.UPNP.Client.ContentDirectory do
  @moduledoc """
  Basic SOAP client for the UPnP ContentDirectory service.
  """

  import Otis.Library.UPNP.Client, only: [envelope: 2, headers: 1]
  import  SweetXml

  require Logger

  alias Otis.Library.UPNP.Server
  alias Otis.Library.UPNP.Server.Service
  alias Otis.Library.UPNP.{Container, Item, Media}

  @search_capabilities_action "urn:schemas-upnp-org:service:ContentDirectory:1#GetSearchCapabilities"
  @browse_action {"urn:schemas-upnp-org:service:ContentDirectory:1", "Browse"}

  @browse_direct_children "BrowseDirectChildren"
  @browse_metadata "BrowseMetadata"

  def get_search_capabilities(%Server{directory: %Service{control_url: addr}}) do
    make_soap_request(addr, @search_capabilities_action, []) |> parse_search_capabilities_response
  end

  def retreive(server, object_id) do
    {:ok, %{items: [item]}} = browse(server, object_id, @browse_metadata)
    {:ok, item}
  end

  def browse(%Server{directory: %Service{control_url: addr}} = server, object_id \\ "0", flag \\ @browse_direct_children, filter \\ "*", starting_index \\ 0, requested_count \\ 0, sort_criteria \\ "") do
    args = [
      {"ObjectID", %{}, object_id},
      {"BrowseFlag", %{}, flag},
      {"Filter", %{}, filter},
      {"StartingIndex", %{}, starting_index},
      {"RequestedCount", %{}, requested_count},
      {"SortCriteria", %{}, sort_criteria},
    ]
    make_soap_request(addr, @browse_action, args) |> parse_browse_response(server)
  end

  def make_soap_request(addr, action, attrs) do
    body = envelope(attrs, action)
    Logger.info "SOAP #{addr} -> #{inspect action} -> #{inspect attrs}"
    HTTPoison.post(addr, body, headers(action))
  end

  def parse_browse_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}, server) do
    # SweetXml chokes on encoded xml within Result tag
    {:ok, dom, _tail} = :erlsom.simple_form(body)
    {'{http://schemas.xmlsoap.org/soap/envelope/}Envelope', _attrs, [envelope]} = dom
    {'{http://schemas.xmlsoap.org/soap/envelope/}Body', _attrs, [body]} = envelope
    {'{urn:schemas-upnp-org:service:ContentDirectory:1}BrowseResponse', _attrs, response} = body
    {'Result', _attrs, [encoded_didl]} = Enum.find(response, fn
      {'Result', _, _} -> true
      _ -> false
    end)
    response =
      encoded_didl |> xmap(
        containers: ~x"/DIDL-Lite//container"l |> transform_by(&parse_containers(&1, server)),
        items: ~x"/DIDL-Lite//item"l |> transform_by(&parse_items(&1, server)),
      )
    {:ok, response}
  end
  def parse_browse_response(resp) do
    Logger.warn "Error response #{inspect resp}"
    {:error, resp}
  end

  @container_map [
    id: ~x"./@id"s,
    parent_id: ~x"./@parentId"s,
    title: ~x"./dc:title/text()"s,
    child_count: ~x"./@childCount"I,
    album_art: ~x"./upnp:albumArtURI/text()"s,
  ]

  @item_map [
    id: ~x"./@id"s,
    parent_id: ~x"./@parentId"s,
    title: ~x"./dc:title/text()"s,
    album: ~x"./upnp:album/text()"s,
    composer: ~x"./dc:creator/text()"s,
    date: ~x"./dc:date/text()"s,
    genre: ~x"./upnp:genre/text()"s,
    artist: ~x"./upnp:artist/text()"s,
    album_art: ~x"./upnp:albumArtURI/text()"s,
  ]

  @media_map [
    uri: ~x"./text()"s,
    size: ~x"./@size"I,
    bitrate: ~x"./@bitrate"I,
    sample_freq: ~x"./@sampleFrequency"I,
    channels: ~x"./@nrAudioChannels"I,
    info: ~x"./@protocolInfo"s,
  ]

  def parse_containers(nodes, server) do
    Enum.map(nodes, &parse_container(&1, server))
  end

  def parse_container(node, _server) do
    struct(%Container{}, xmap(node, @container_map))
  end

  def parse_items(nodes, server) do
    Enum.map(nodes, &parse_item(&1, server))
  end

  def parse_item(node, server) do
    struct(%Item{device_id: server.id}, xmap(node, item_map()))
  end

  defp item_map do
    [{:media, ~x"./res" |> transform_by(&parse_media/1)} | @item_map]
  end

  def parse_media(node) do
    struct(%Media{}, xmap(node, media_map()))
  end

  defp media_map do
    [{:duration, ~x"./@duration"s |> transform_by(&calculate_duration/1)} | @media_map]
  end

  def calculate_duration(duration) do
    [h, m, s] = String.split(duration, ":")
    (1000 * (String.to_integer(h) * 3600 + String.to_integer(m) * 60 + String.to_float(s))) |> round
  end

  def parse_search_capabilities_response({:ok, %HTTPoison.Response{status_code: 200, body: _body}}) do
  end
  def parse_search_capabilities_response(resp) do
    Logger.warn "Error response #{inspect resp}"
  end
end
