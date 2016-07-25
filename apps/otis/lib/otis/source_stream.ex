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

  @doc "Closes the streams"
  def close(pid) do
    GenServer.call(pid, :close)
  end

  @doc "Pauses the input stream"
  def pause(pid) do
    GenServer.call(pid, :pause)
  end

  @doc "Resumes the input stream"
  def resume(pid) do
    GenServer.call(pid, :resume)
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
    {:ok, pid} = Otis.SourceStreamSupervisor.start(id, source, playback_position)
    {:ok, duration} = Otis.Library.Source.duration(source)
    {:ok, id, playback_position, duration, pid}
  end

  def start_link(id, source, playback_position) do
    state = %{
      id: id,
      source: source,
      playback_position: playback_position,
      outputstream: nil,
      inputstream: nil,
      transcode_pid: nil,
      pending_streams: nil
    }
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  def terminate(reason, state) do
    :ok
  end

  def handle_call(:chunk, _from, state) do
    next_chunk(state)
  end

  def handle_call(:close, _from, state) do
    Otis.Library.Source.close(state.source, state.id, state.inputstream)
    {:reply, :ok, state}
  end
  def handle_call(:pause, _from, state) do
    Otis.Library.Source.pause(state.source, state.id, state.inputstream)
    {:reply, :ok, state}
  end
  def handle_call(:resume, _from, state) do
    {reply, state} =
      case Otis.Library.Source.resume!(state.source, state.id, state.inputstream) do
        {:reuse, _stream} ->
          {:resume, state}
        {:reopen, stream} ->
          state = state
          |> close_transcoder()
          |> open_transcoder(stream)
          {:flush, state}
      end
    {:reply, reply, state}
  end

  def handle_call(:source_info, _from, state) do
    {:reply, {:ok, state.source}, state}
  end

  def handle_info({:EXIT, _from, _reason}, state) do
    {:noreply, state}
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

  defp next_chunk(_chunk, %{id: id, source: source, inputstream: inputstream} = state) do
    Otis.Library.Source.close(source, id, inputstream)
    state = close_transcoder(state)
    {:stop,
      {:shutdown, :done},
      :done, # reply
      %{state | inputstream: nil, outputstream: nil, transcode_pid: nil}
    }
  end

  defp open(%{pending_streams: nil} = state) do
    inputstream = input_stream(state)
    open_transcoder(state, inputstream)
  end

  defp open_transcoder(state, inputstream) do
    { pid, outputstream } = Otis.Transcoders.Avconv.transcode(inputstream, stream_type(state), state.playback_position)
    %{state | pending_streams: {inputstream, outputstream, pid} }
  end

  defp close_transcoder(state) do
    Otis.Transcoders.Avconv.stop(state.transcode_pid)
    %{ state | outputstream: nil, transcode_pid: nil, pending_streams: nil }
  end

  defp open(state) do
    state
  end

  defp input_stream(%{ id: id, source: source }) do
    Otis.Library.Source.open!(source, id, Otis.stream_bytes_per_step * 4)
  end

  defp stream_type(%{ source: source }) do
    {ext, _mime_type} = Otis.Library.Source.audio_type(source)
    ext
  end
end
