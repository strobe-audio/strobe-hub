defmodule Otis.Library.Airplay.Events.Library do
  use     GenStage
  require Logger

  @ns "airplay"

  use  Otis.Library, namespace: @ns
  alias Otis.Library.Airplay

  if Code.ensure_compiled?(Otis.Media) do
    def setup(state) do
      image_dir = [:code.priv_dir(:otis_library_airplay), "static"] |> Path.join |> Path.expand
      Otis.Media.copy!(Airplay.library_id(), "airplay.svg", Path.join([image_dir, "strobe-airplay.svg"]))
      Otis.Media.copy!(Airplay.library_id(), "airplay-1.svg", Path.join([image_dir, "strobe-airplay-1.svg"]))
      Otis.Media.copy!(Airplay.library_id(), "airplay-2.svg", Path.join([image_dir, "strobe-airplay-2.svg"]))
      state
    end

    def airplay_logo(id \\ nil)
    def airplay_logo(nil) do
      Otis.Media.url(Airplay.library_id(), "airplay.svg")
    end
    def airplay_logo(id) do
      Otis.Media.url(Airplay.library_id(), "airplay-#{id}.svg")
    end
  else
    def setup(state) do
      state
    end

    def airplay_logo(_id \\ nil) do
      "airplay.svg"
    end
  end

  def library do
    %{ id: Airplay.library_id,
      title: "Airplay",
      icon: airplay_logo(),
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
      section(%{ id: "#{@ns}:#{input.id}", title: "Strobe #{input.id}", size: "m", icon: airplay_logo(input.id), actions: %{ click: %{ url: url("input/#{input.id}/play"), level: false }, play: %{ url: url("input/#{input.id}/play"), level: false } }, metadata: nil, children: [] })
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
