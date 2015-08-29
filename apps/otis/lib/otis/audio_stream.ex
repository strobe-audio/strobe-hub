defmodule Otis.AudioStream do
  @moduledoc """
  Transforms a source of sources into a byte stream chunked according to the
  bit rate of the desired audio stream
  """

  use GenServer
  require Logger

  defmodule S do
    defstruct source_stream: nil, source: nil, buffer: <<>>, chunk_size: 3528, state: :stopped
  end

  def frame(pid) do
    GenServer.call(pid, :frame)
  end

  @doc """
  Create a new source list with the given SourceSource which is anything that
  implements Enumerable
  """
  def start_link(source_stream, chunk_size) do
    GenServer.start_link(__MODULE__, %S{source_stream: source_stream, chunk_size: chunk_size})
  end

  def start_link(source_stream) do
    GenServer.start_link(__MODULE__, %S{source_stream: source_stream})
  end

  def handle_call(:frame, _from, %S{source: nil, state: :stopped} = state) do
    state = %S{ state | state: :starting }
    {:ok, frame, state } = audio_frame(state)
    {:reply, frame, state}
  end

  def handle_call(:frame, _from, state) do
    {:ok, frame, state } = audio_frame(state)
    {:reply, frame, state}
  end

  defp audio_frame(%S{source: nil, state: :starting} = state) do
    state = current_source(state)
    audio_frame(state)
  end

  defp audio_frame(%S{ state: :stopped, buffer: buffer } = state) when byte_size(buffer) > 0 do
    {:ok, { :ok, buffer }, %S{state | buffer: <<>> }}
  end

  defp audio_frame(%S{ state: :stopped, buffer: buffer } = state) when byte_size(buffer) == 0 do
    {:ok, :stopped, %S{ state | source: nil} }
  end

  defp audio_frame(%S{ source: nil, buffer: buffer, chunk_size: chunk_size} = state) when byte_size(buffer) < chunk_size do
    audio_frame(current_source(state))
  end

  defp audio_frame(%S{ source: source, buffer: buffer, chunk_size: chunk_size} = state) when byte_size(buffer) < chunk_size do
    Otis.Source.chunk(source) |> append_and_send(state)
  end

  defp audio_frame(%S{ buffer: buffer, chunk_size: chunk_size } = state) do
    << frame :: binary-size(chunk_size), rest :: binary >> = buffer
    {:ok, {:ok, frame }, %S{ state | buffer: rest } }
  end

  defp append_and_send({:ok, data}, %S{buffer: buffer } = state) do
    state = %S{ state | buffer: << buffer <> data >> }
    audio_frame(state)
  end

  defp append_and_send(:done, state) do
    audio_frame(%S{state | source: nil})
  end

  defp current_source(%S{source_stream: source_stream, source: nil} = state) do
    case Otis.SourceStream.next(source_stream) do
      {:ok, source } ->
        %S{ state | source: source, state: :playing }
      :done ->
        %S{ state | state: :stopped }
    end
  end

  defp current_source(state) do
    state
  end
end

