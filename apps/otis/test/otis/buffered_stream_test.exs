defmodule Test.ArrayAudioStream do
  use GenServer

  def start_link(source_id, frames) do
    GenServer.start_link(__MODULE__, {frames, source_id})
  end

  def init({frames, source_id}) do
    {:ok, {frames, source_id, []}}
  end

  def handle_call(:frame, _from, {[], _, _} = state) do
    {:reply, :stopped, state}
  end

  def handle_call(:frame, _from, {[ frame | frames ], source_id, sent}) do
    {:reply, {:ok, source_id, frame}, {frames, source_id, [frame | sent]}}
  end

  def handle_call(:sent, _from, {frames, source_id, sent}) do
    {:reply, {:ok, Enum.reverse(sent)}, {frames, source_id, []}}
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

  test "buffered stream allows for pre-filling without affecting delivered packets" do
    source_id = "source-1"
    buffer_size = 8
    packets = (1..100) |> Enum.map(&Integer.to_string(&1, 10))
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, packets)
    {:ok, buffered_stream} = Otis.Zone.BufferedStream.start_link(audio_stream, buffer_size)
    :ok = Otis.AudioStream.buffer(buffered_stream)
    {:ok, sent} = GenServer.call(audio_stream, :sent)
    assert sent == Enum.take(packets, buffer_size)
    Enum.each packets, fn(p) ->
      {:ok, ^source_id, ^p} = Otis.AudioStream.frame(buffered_stream)
    end
    :stopped = Otis.AudioStream.frame(buffered_stream)
  end

  test "calling buffer multiple times does nothing" do
    source_id = "source-1"
    buffer_size = 8
    packets = (1..100) |> Enum.map(&Integer.to_string(&1, 10))
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, packets)
    {:ok, buffered_stream} = Otis.Zone.BufferedStream.start_link(audio_stream, buffer_size)

    :ok = Otis.AudioStream.buffer(buffered_stream)
    {:ok, sent} = GenServer.call(audio_stream, :sent)
    assert sent == Enum.take(packets, buffer_size)

    :ok = Otis.AudioStream.buffer(buffered_stream)
    {:ok, sent} = GenServer.call(audio_stream, :sent)
    assert sent == []

    :ok = Otis.AudioStream.buffer(buffered_stream)
    {:ok, sent} = GenServer.call(audio_stream, :sent)
    assert sent == []

    Enum.each packets, fn(p) ->
      {:ok, ^source_id, ^p} = Otis.AudioStream.frame(buffered_stream)
    end
    :stopped = Otis.AudioStream.frame(buffered_stream)
  end
end

