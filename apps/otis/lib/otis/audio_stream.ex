defmodule Otis.AudioStream do
  @moduledoc """
  Transforms a source of sources into a byte stream chunked according to the
  bit rate of the desired audio stream
  """

  alias Otis.AudioStream, as: AS
  use GenServer

  defstruct source_stream: nil, source: nil, buffer: <<>>, chunk_size: 3528, state: :playing

  def frame(pid) do
    GenServer.call(pid, :frame)
  end

  @doc """
  Create a new source list with the given SourceSource which is anything that
  implements Enumerable
  """
  def start_link(source_stream, chunk_size) do
    GenServer.start_link(__MODULE__, %AS{source_stream: source_stream, chunk_size: chunk_size})
  end

  def start_link(source_stream) do
    GenServer.start_link(__MODULE__, %AS{source_stream: source_stream})
  end

  def handle_call(:frame, _from, audio_stream) do
    {:ok, frame, audio_stream } = audio_frame(audio_stream)
    {:reply, frame, audio_stream}
  end

  defp audio_frame(%AS{ state: :done, buffer: buffer } = audio_stream) when byte_size(buffer) > 0 do
    {:ok, { :ok, buffer }, %AS{audio_stream | buffer: <<>> }}
  end

  defp audio_frame(%AS{ state: :done, buffer: buffer } = audio_stream) when byte_size(buffer) == 0 do
    {:ok, :done, audio_stream}
  end

  defp audio_frame(%AS{source: nil} = audio_stream) do
    audio_stream = current_source(audio_stream)
    audio_frame(audio_stream)
  end

  defp audio_frame(%AS{ source: source, buffer: buffer, chunk_size: chunk_size} = audio_stream) when byte_size(buffer) < chunk_size do
    Otis.Source.chunk(source) |> append_and_send(audio_stream)
  end

  defp audio_frame(%AS{ buffer: buffer, chunk_size: chunk_size } = audio_stream) do
    << frame :: binary-size(chunk_size), rest :: binary >> = buffer
    {:ok, {:ok, frame }, %AS{ audio_stream | buffer: rest } }
  end

  defp append_and_send({:ok, data}, %AS{buffer: buffer } = audio_stream) do
    audio_stream = %AS{ audio_stream | buffer: << buffer <> data >> }
    audio_frame(audio_stream)
  end

  defp append_and_send(:done, audio_stream) do
    audio_frame(%AS{audio_stream | source: nil})
  end

  defp current_source(%AS{source_stream: source_stream, source: nil} = audio_stream) do
    case Otis.SourceStream.next(source_stream) do
      {:ok, source } ->
        %AS{ audio_stream | source: source }
      :done ->
        %AS{ audio_stream | state: :done }
    end
  end

  defp current_source(audio_stream) do
    audio_stream
  end
end

