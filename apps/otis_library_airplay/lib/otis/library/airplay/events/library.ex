defmodule Otis.Library.Airplay.Events.Library do
  use     GenEvent
  require Logger

  @ns "airplay"

  use  Otis.Library, namespace: @ns
  alias Otis.Library.Airplay

  def event_handler do
    {__MODULE__, []}
  end

  def setup(state) do
    state
  end

  def library do
    %{ id: Airplay.library_id,
      title: "Airplay",
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
    inputs = Airplay.inputs()
    children = Enum.map(inputs, fn(input) ->
      section(%{ id: "#{@ns}:#{input.id}", title: "Strobe #{input.id}", size: "m", icon: "", actions: %{ click: %{ url: url("input/#{input.id}/play"), level: false }, play: %{ url: url("input/#{input.id}/play"), level: false } }, metadata: nil, children: [] })
    end)
    %{
      id: "#{@ns}:root",
      title: "Airplay",
      icon: "",
      search: nil,
      length: length(children),
      children: children,
    }
  end
  def route_library_request(channel_id, ["input", input_id, "play"], _query, _path) do
    Airplay.input(input_id) |> play(channel_id)
  end
end
