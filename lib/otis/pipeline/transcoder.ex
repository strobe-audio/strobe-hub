defmodule Otis.Pipeline.Transcoder do
  use GenServer

  alias Otis.Library.Source

  defstruct [:id, :pid]

  defmodule S do
    defstruct [
      :source,
      :inputstream,
      :playback_position,
      :transcoder_pid,
      :outputstream,
    ]
  end

  def new(id, source, inputstream, playback_position) do
    {:ok, pid} = start_link(source, inputstream, playback_position)
    %__MODULE__{id: id, pid: pid}
  end

  def next(pid) do
    GenServer.call(pid, :next)
  end

  def start_link(source, inputstream, playback_position) do
    GenServer.start_link(__MODULE__, [source, inputstream, playback_position])
  end

  def init([source, inputstream, playback_position]) do
    state = %S{
      source: source,
      inputstream: inputstream,
      playback_position: playback_position,
    } |> start()
    {:ok, state}
  end


  def handle_call(:next, _from, state) do
    resp = case Enum.take(state.outputstream, 1) do
      [] -> :done
      [data] -> {:ok, data}
    end
    {:reply, resp, state}
  end

  defp start(state) do
    {ext, type} = Source.audio_type(state.source)
    {pid, outputstream} = Otis.Transcoders.Avconv.transcode(state.inputstream, ext, state.playback_position)
    %S{ state | transcoder_pid: pid, outputstream: outputstream }
  end
end

defimpl Otis.Pipeline.Producer, for: Otis.Pipeline.Transcoder do
  alias Otis.Pipeline.Transcoder

  def next(transcoder) do
    Transcoder.next(transcoder.pid)
  end
end
