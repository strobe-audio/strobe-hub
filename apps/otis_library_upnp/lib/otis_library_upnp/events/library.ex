defmodule Otis.Library.UPNP.Events.Library do
  use     GenEvent
  require Logger

  @ns "upnp"

  use  Otis.Library, namespace: @ns
  alias Otis.Library.UPNP
  alias Otis.Library.UPNP.{Container, Item, Media}

  def event_handler do
    {__MODULE__, []}
  end

  def setup(state) do
    state
  end

  def library do
    %{ id: UPNP.library_id,
      title: "UPnP",
      icon: "",
      size: "m",
      actions: %{
        click: %{ url: url("root"), level: true },
        play: nil,
      },
      metadata: nil,
      children: [],
      length: 0,
    }
  end

  def route_library_request(_channel_id, ["root"], _query, _path) do
    {:ok, devices} = UPNP.Discovery.all
    children = Enum.map(devices, fn(device) ->
        section(%{ id: "#{@ns}:#{device.id}", title: device.name, size: "m", icon: "", actions: %{ click: %{ url: url("device/#{device.id}"), level: true }, play: nil }, metadata: nil, children: [] })
    end)
    %{
      id: "#{@ns}:root",
      title: "UPnP Servers",
      icon: "",
      search: nil,#%{url: search_url("root"), title: "your music" },
      length: length(children),
      children: children,
    }
  end
  def route_library_request(_channel_id, ["device", device_id], _query, _path) do
    {:ok, %{containers: containers}} =
      device_id |> lookup!() |> UPNP.Client.ContentDirectory.browse()

    children =
      containers
      |> Enum.map(fn(%Container{} = container) ->
        section(%{ id: "#{@ns}:container:#{container.id}", title: container.title, size: "m", icon: "", actions: %{ click: click_action(device_id, container), play: nil }, metadata: nil, children: [] })
      end)

    %{
      id: "#{@ns}:root",
      title: "UPnP Servers",
      icon: "",
      search: nil,#%{url: search_url("root"), title: "your music" },
      length: length(children),
      children: children,
    }
  end

  def route_library_request(_channel_id, ["device", device_id, "container", container_id], _query, path) do
    {:ok, %{containers: containers, items: items}} =
      device_id |> lookup!() |> UPNP.Client.ContentDirectory.browse(container_id)

    folders =
      containers
      |> Enum.map(&folder_node(device_id, &1))
      # |> Enum.group_by(&alphabetical_section/1)
      # |> Enum.map(&_section/1)
      # |> Enum.sort_by(fn(s) -> s.title end)

    media =
      items
      |> Enum.map(&folder_node(device_id, &1))

    children =

      [ section(%{
          id: namespaced(path),
          title: "Folders",
          size: "s",
          children: folders,
        }),
        section(%{
          id: namespaced(path),
          title: "Media",
          size: "s",
          children: media,
        }),
      ]

    %{
      id: path,
      title: "Need name of parent",
      icon: "",
      search: nil,#%{url: search_url("root"), title: "your music" },
      length: length(children),
      children: children,
    }
  end

  def route_library_request(channel_id, ["device", device_id, "item", item_id, "play"], _query, _path) do
    {:ok, item} =
      device_id
      |> lookup!()
      |> UPNP.Client.ContentDirectory.retreive(item_id)
    play(item, channel_id)
  end

  defp lookup!(id) do
    UPNP.Discovery.lookup!(id)
  end

  defp folder_node(device_id, %Item{} = node)do
    %{
      title: node.title,
      icon: icon(node.album_art),
      actions: %{
        click: click_action(device_id, node),
        play: play_action(device_id, node)
      },
      metadata: [
        [%{title: Media.duration_string(node.media), action: nil}],
      ],
    }
  end
  defp folder_node(device_id, %Container{} = node)do
    %{
      title: node.title,
      icon: icon(node.album_art),
      actions: %{
        click: click_action(device_id, node),
        play: play_action(device_id, node)
      },
      metadata: [
      ],
    }
  end

  def click_action(device_id, %Item{} = item) do
    play_action(device_id, item)
  end
  def click_action(device_id, %Container{id: id}) do
    %{ url: url(["device", device_id, "container", id]), level: true }
  end

  def play_action(device_id, %Item{id: id}) do
    %{ url: url(["device", device_id, "item", id, "play"]), level: false }
  end
  def play_action(device_id, %Container{id: id}) do
    %{ url: url(["device", device_id, "container", id, "play"]), level: false }
  end

  def alphabetical_section(element, field \\ :title) do
    Map.get(element, field, "") |> String.first |> String.upcase |> grouped_alphabetical
  end

  @letters 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

  def grouped_alphabetical(<<l::utf8>>) when l in @letters do
    <<l::utf8>>
  end
  def grouped_alphabetical(_l) do
    "#"
  end

  def _section({letter, children}) do
    %{ id: "", title: letter, children: children } |> section
  end

  def icon(nil), do: ""
  def icon(icon), do: icon
end
