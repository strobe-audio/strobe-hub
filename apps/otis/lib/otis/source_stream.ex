defmodule Otis.SourceStream do
  @moduledoc """
  Given a Source instance returns a process that will open the source and read
  chunks of data from it.
  """

  require Logger
  use     GenServer

  @doc "Gives the next chunk of data from the source"
  def chunk(pid) do
    GenServer.call(pid, :chunk, 30_000)
  end

  @doc """
  Returns info about the current source. This will vary according to the source
  type but should conform to some kind of as-yet-determined api.
  """
  def info(pid) do
    GenServer.call(pid, :source_info)
  end

  @doc "Returns a new SourceStream for the given source"
  def new(id, playback_position, source) do
    {:ok, pid} = Otis.SourceStreamSupervisor.start(source, playback_position)
    {:ok, duration} = Otis.Source.duration(source)
    {:ok, id, playback_position, duration, pid}
  end

  def start_link(source, playback_position) do
    state = %{
      source: source,
      playback_position: playback_position,
      outputstream: nil,
      inputstream: nil,
      transcode_pid: nil,
      pending_streams: nil
    }
    GenServer.start_link(__MODULE__, state)
  end

  def handle_call(:chunk, _from, state) do
    next_chunk(state)
  end

  def handle_call(:source_info, _from, state) do
    {:reply, {:ok, state.source}, state}
  end

  defp next_chunk(%{outputstream: nil, pending_streams: nil} = state) do
    next_chunk(open(state))
  end

  defp next_chunk(%{outputstream: nil, pending_streams: {inputstream, outputstream, pid}} = state) do
    state = %{ state | inputstream: inputstream, outputstream: outputstream, transcode_pid: pid, pending_streams: nil }
    next_chunk(state)
  end

  defp next_chunk(%{outputstream: outputstream} = state) do
    outputstream |> Enum.fetch(0) |> next_chunk(state)
  end

  defp next_chunk({:ok, _} = chunk, state) do
    {:reply, chunk, state}
  end

  defp next_chunk(:error, %{source: source, inputstream: inputstream} = state) do
    Otis.Source.close(source, inputstream)
    {:stop,
      {:shutdown, :done},
      :done, # reply
      %{state | inputstream: nil, outputstream: nil, transcode_pid: nil}
    }
  end

  defp open(%{pending_streams: nil, playback_position: playback_position} = state) do
    inputstream = input_stream(state)
    { pid, outputstream } = Otis.Transcoders.Avconv.transcode(inputstream, stream_type(state), playback_position)
    %{state | pending_streams: {inputstream, outputstream, pid} }
  end

  defp open(state) do
    state
  end

  defp input_stream(%{ source: source }) do
    Otis.Source.open!(source, Otis.stream_bytes_per_step * 4)
  end

  defp stream_type(%{ source: source }) do
    {ext, _mime_type} = Otis.Source.audio_type(source)
    ext
  end
end
