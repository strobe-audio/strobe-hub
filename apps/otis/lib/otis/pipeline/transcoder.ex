defmodule Otis.Pipeline.Transcoder do
  use GenServer

  require Logger

  alias Otis.Library.Source
  alias Otis.Transcoders.Avconv

  defmodule S do
    defstruct [
      :source,
      :inputstream,
      :playback_position,
      :transcoder,
      :outputstream,
    ]
  end

  def start_link(source, inputstream, playback_position, config) do
    GenServer.start_link(__MODULE__, [source, inputstream, playback_position, config])
  end

  def init([source, inputstream, playback_position, config]) do
    # Ensure we get the terminate/2 callback
    Process.flag(:trap_exit, true)
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

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.debug "#{__MODULE__} got EXIT from #{inspect pid}: #{inspect reason}"
    {:noreply, state}
  end
  def handle_info(msg, state) do
    Logger.warn "#{__MODULE__} Unhandled message handle_info/2 #{inspect msg}"
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.debug "#{__MODULE__} terminate #{inspect reason}"
    Avconv.stop(state.transcoder)
    :ok
  end

  defp start(state, config) do
    {ext, _type} = Source.audio_type(state.source)
    {pid, outputstream} = Avconv.transcode(state.inputstream, ext, state.playback_position, config)
    %S{ state | transcoder: pid, outputstream: outputstream }
  end
end
