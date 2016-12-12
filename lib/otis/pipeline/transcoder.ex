defmodule Otis.Pipeline.Transcoder do
  use GenServer

  alias Otis.Library.Source

  defmodule S do
    defstruct [
      :source,
      :inputstream,
      :playback_position,
      :transcoder_pid,
      :outputstream,
    ]
  end

  def start_link(source, inputstream, playback_position, config) do
    GenServer.start_link(__MODULE__, [source, inputstream, playback_position, config])
  end

  def init([source, inputstream, playback_position, config]) do
    state = %S{
      source: source,
      inputstream: inputstream,
      playback_position: playback_position,
    } |> start(config)
    {:ok, state}
  end


  def handle_call(:next, _from, state) do
    resp = case Enum.take(state.outputstream, 1) do
      [] -> :done
      [data] -> {:ok, data}
    end
    {:reply, resp, state}
  end

  defp start(state, config) do
    {ext, _type} = Source.audio_type(state.source)
    {pid, outputstream} = Otis.Transcoders.Avconv.transcode(state.inputstream, ext, state.playback_position, config)
    %S{ state | transcoder_pid: pid, outputstream: outputstream }
  end
end
