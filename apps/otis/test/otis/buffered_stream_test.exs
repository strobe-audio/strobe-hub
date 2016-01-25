defmodule Test.ArrayAudioStream do
  use GenServer

  def start_link(source_id, frames) do
    GenServer.start_link(__MODULE__, {frames, source_id})
  end

  def init({frames, source_id}) do
    {:ok, {frames, source_id}}
  end

  def handle_call(:frame, _from, {[], _} = state) do
    {:reply, :stopped, state}
  end

  def handle_call(:frame, _from, {[ frame | frames ], source_id}) do
    {:reply, {:ok, source_id, frame}, {frames, source_id}}
  end
end

defmodule Otis.BufferedStreamTest do
  use   ExUnit.Case, async: true
  setup do
    :ok
  end

  test "audio stream returns :stopped immediately if the stream is empty" do
    source_id = "source-1"
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, [])
    :stopped = Otis.AudioStream.frame(audio_stream)
  end

  test "audio stream returns all the frames for a short stream" do
    source_id = "source-1"
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, [
      "01",
      "02",
      "03",
      "04"
    ])
    {:ok, ^source_id, "01"} = Otis.AudioStream.frame(audio_stream)
    {:ok, ^source_id, "02"} = Otis.AudioStream.frame(audio_stream)
    {:ok, ^source_id, "03"} = Otis.AudioStream.frame(audio_stream)
    {:ok, ^source_id, "04"} = Otis.AudioStream.frame(audio_stream)
    :stopped = Otis.AudioStream.frame(audio_stream)
  end

  test "buffered stream returns :stopped immediately if the stream is empty" do
    source_id = "source-1"
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, [])
    {:ok, buffered_stream} = Otis.Zone.BufferedStream.seconds(audio_stream, 1)
    :stopped = Otis.AudioStream.frame(buffered_stream)
  end

  test "buffered stream returns all the frames for a short stream" do
    source_id = "source-1"
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, [
      "01",
      "02",
      "03",
      "04"
    ])

    {:ok, buffered_stream} = Otis.Zone.BufferedStream.seconds(audio_stream, 1)
    {:ok, ^source_id, "01"} = Otis.AudioStream.frame(buffered_stream)
    {:ok, ^source_id, "02"} = Otis.AudioStream.frame(buffered_stream)
    {:ok, ^source_id, "03"} = Otis.AudioStream.frame(buffered_stream)
    {:ok, ^source_id, "04"} = Otis.AudioStream.frame(buffered_stream)
    :stopped = Otis.AudioStream.frame(buffered_stream)
  end
end

