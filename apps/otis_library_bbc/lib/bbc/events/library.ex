defmodule BBC.Events.Library do
  use     GenEvent
  require Logger
  alias   BBC.Channel


  use  Otis.Library, namespace: BBC.library_id()

  if Code.ensure_loaded?(Otis.State.Events) do
    def register do
      Otis.State.Events.add_mon_handler(__MODULE__, [])
    end
  else
    def register do
      :ok
    end
  end

  def setup(state) do
    image_dir = [__DIR__, ".."] |> Path.join |> Path.expand
    Otis.Media.copy!(BBC.library_id(), "bbc.svg", Path.join([image_dir, "bbc.svg"]))
    image_dir = [__DIR__, "../channels"] |> Path.join |> Path.expand
    Enum.each BBC.channels(), fn(channel) ->
      Enum.each ["small", "large"], fn(size) ->
        logo = Channel.logo(channel, size)
        svg = Path.join([image_dir, logo])
        if File.exists?(svg) do
          Otis.Media.copy!(BBC.library_id(), logo, svg)
        end
      end
    end
    state
  end

  def bbc_logo do
    Otis.Media.url(BBC.library_id(), "bbc.svg")
  end

  def library do
    %{ id: BBC.library_id(),
      title: "BBC",
      icon: bbc_logo(),
      size: "m",
      actions: %{
        click: %{ url: url("root"), level: true },
        play: nil
      },
      metadata: nil,
      children: [],
      length: 0,
    }
  end

  def route_library_request(_channel_id, ["root"], _query, _path) do
    channels = Enum.map BBC.channels(), fn(channel) ->
      play = %{ url: url(["channel", channel.id, "play"]), level: false }
      %{ id: "bbc:channel/#{channel.id}",
        title: channel.title,
        icon: Channel.cover_image(channel, :small),
        actions: %{ click: play, play: play },
        metadata: nil
      }
    end
    section = %{
      id: Enum.join([BBC.library_id(), "channels"], ":"),
      title: "BBC Radio",
      size: "m",
      children: channels
    } |> section()

    %{
      id: "bbc:root",
      title: "BBC",
      icon: bbc_logo(),
      search: nil,
      children: [section],
    }
  end
  def route_library_request(channel_id, ["channel", id, "play"], _query, _path) do
    id
    |> BBC.find!
    |> play(channel_id)
  end
end
