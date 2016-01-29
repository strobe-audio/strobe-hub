defmodule Otis.AudioStream do
  @moduledoc """
  Transforms a source of sources into a byte stream chunked according to the
  bit rate of the desired audio stream
  """

  use GenServer
  require Logger

  defmodule S do
    defstruct source_list: nil, source_id: nil, source: nil, buffer: <<>>, chunk_size: 3528, state: :stopped
  end

  def frame(pid) do
    GenServer.call(pid, :frame)
  end

  def buffer(pid) do
    GenServer.call(pid, :buffer)
  end

  @doc """
  Create a new source list with the given SourceSource which is anything that
  implements Enumerable
  """
  def start_link(source_list, chunk_size) do
    GenServer.start_link(__MODULE__, %S{source_list: source_list, chunk_size: chunk_size})
  end

  def start_link(source_list) do
    GenServer.start_link(__MODULE__, %S{source_list: source_list})
  end

  # TODO: Do I need to implement this
  def handle_call(:buffer, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call(:frame, _from, %S{source: nil, state: :stopped} = state) do
    state = %S{ state | state: :starting }
    {:frame, frame, state } = audio_frame(state)
    {:reply, frame, state}
  end

  def handle_call(:frame, _from, state) do
    {:frame, frame, state } = audio_frame(state)
    {:reply, frame, state}
  end

  def handle_call(:flush, _from, state) do
    {:reply, :ok, %S{ state | source: nil, state: :stopped, buffer: <<>> }}
  end

  defp audio_frame(%S{source: nil, state: :starting} = state) do
    audio_frame(enumerate_source(state))
  end

  defp audio_frame(%S{ state: :stopped, buffer: buffer } = state)
  when byte_size(buffer) > 0 do
    {:frame, { :ok, state.source_id, buffer }, %S{state | buffer: <<>> }}
  end

  defp audio_frame(%S{ state: :stopped, buffer: buffer } = state)
  when byte_size(buffer) == 0 do
    {:frame, :stopped, %S{ state | source: nil} }
  end

  defp audio_frame(%S{ source: nil, buffer: buffer, chunk_size: chunk_size} = state)
  when byte_size(buffer) < chunk_size do
    audio_frame(enumerate_source(state))
  end

  defp audio_frame(%S{ source: source, buffer: buffer, chunk_size: chunk_size} = state)
  when byte_size(buffer) < chunk_size do
    source |> Otis.SourceStream.chunk |> append_and_send(state)
  end

  defp audio_frame(%S{ buffer: buffer, chunk_size: chunk_size } = state) do
    << data :: binary-size(chunk_size), rest :: binary >> = buffer
    frame = {:ok, state.source_id, data}
    {:frame, frame, %S{ state | buffer: rest } }
  end

  defp append_and_send({:ok, data}, %S{buffer: buffer } = state) do
    audio_frame(%S{ state | buffer: << buffer <> data >> })
  end

  defp append_and_send(:done, state) do
    audio_frame(%S{state | source: nil})
  end

  defp enumerate_source(%S{source_list: source_list, source: nil} = state) do
    case open_source(Otis.SourceList.next(source_list)) do
      {:ok, id, source_stream} ->
        %S{ state | source_id: id, source: source_stream, state: :playing }
      :done ->
        %S{ state | state: :stopped }
    end
  end
  defp enumerate_source(state) do
    state
  end

  defp open_source(:done) do
    :done
  end
  defp open_source({:ok, id, source}) do
    Otis.SourceStream.new(id, source)
  end
end
