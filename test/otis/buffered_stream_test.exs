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
    packet = source_id |> TestUtils.packet |> Otis.Packet.attach(frame)
    {:reply, {:ok, packet}, {frames, source_id, [packet | sent]}}
  end

  def handle_call(:sent, _from, {frames, source_id, sent}) do
    {:reply, {:ok, Enum.reverse(sent)}, {frames, source_id, []}}
  end
end

defmodule Otis.BufferedStreamTest do
  use   ExUnit.Case, async: true
  alias Otis.Packet

  setup do
    :ok
  end

  test "audio stream returns :stopped immediately if the stream is empty" do
    source_id = Otis.uuid
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, [])
    :stopped = Otis.AudioStream.frame(audio_stream)
  end

  test "audio stream returns all the frames for a short stream" do
    source_id = Otis.uuid
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, [
      "01",
      "02",
      "03",
      "04"
    ])
    assert {:ok, %Packet{ TestUtils.packet(source_id) | data: "01" }} == Otis.AudioStream.frame(audio_stream)
    assert {:ok, %Packet{ TestUtils.packet(source_id) | data: "02" }} == Otis.AudioStream.frame(audio_stream)
    assert {:ok, %Packet{ TestUtils.packet(source_id) | data: "03" }} == Otis.AudioStream.frame(audio_stream)
    assert {:ok, %Packet{ TestUtils.packet(source_id) | data: "04" }} == Otis.AudioStream.frame(audio_stream)
    :stopped = Otis.AudioStream.frame(audio_stream)
  end

  test "buffered stream returns :stopped immediately if the stream is empty" do
    source_id = Otis.uuid
    stream_id = Otis.uuid
    stream_config = Otis.Stream.Config.seconds(1)
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, [])
    {:ok, buffered_stream} = Otis.Channel.BufferedStream.start_link(stream_id, stream_config, audio_stream)
    :stopped = Otis.AudioStream.frame(buffered_stream)
  end

  test "buffered stream returns all the frames for a short stream" do
    source_id = Otis.uuid
    stream_id = Otis.uuid
    stream_config = Otis.Stream.Config.seconds(1)

    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, [
      "01",
      "02",
      "03",
      "04"
    ])

    {:ok, buffered_stream} = Otis.Channel.BufferedStream.start_link(stream_id, stream_config, audio_stream)
    assert {:ok, %Packet{ TestUtils.packet(source_id) | data: "01" }} == Otis.AudioStream.frame(buffered_stream)
    assert {:ok, %Packet{ TestUtils.packet(source_id) | data: "02" }} == Otis.AudioStream.frame(buffered_stream)
    assert {:ok, %Packet{ TestUtils.packet(source_id) | data: "03" }} == Otis.AudioStream.frame(buffered_stream)
    assert {:ok, %Packet{ TestUtils.packet(source_id) | data: "04" }} == Otis.AudioStream.frame(buffered_stream)
    :stopped = Otis.AudioStream.frame(buffered_stream)
  end

  test "buffered stream allows for pre-filling without affecting delivered packets" do
    source_id = Otis.uuid
    stream_id = Otis.uuid
    stream_config = Otis.Stream.Config.new(8)
    buffer_size = 8
    data = (1..100) |> Enum.map(&Integer.to_string(&1, 10))
    packets = data |> Enum.map(&%Packet{ TestUtils.packet(source_id) | data: &1 })
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, data)
    {:ok, buffered_stream} = Otis.Channel.BufferedStream.start_link(stream_id, stream_config, audio_stream)
    :ok = Otis.AudioStream.buffer(buffered_stream)
    {:ok, sent} = GenServer.call(audio_stream, :sent)
    assert sent == packets |> Enum.take(buffer_size)
    Enum.each packets, fn(p) ->
      assert {:ok, p} == Otis.AudioStream.frame(buffered_stream)
    end
    :stopped = Otis.AudioStream.frame(buffered_stream)
  end

  test "calling buffer multiple times does nothing" do
    source_id = Otis.uuid
    stream_id = Otis.uuid
    stream_config = Otis.Stream.Config.new(8)
    buffer_size = 8
    data = (1..100) |> Enum.map(&Integer.to_string(&1, 10))

    packets = data |> Enum.map(fn(data) ->
      Packet.attach TestUtils.packet(source_id), data
    end)
    {:ok, audio_stream} = Test.ArrayAudioStream.start_link(source_id, data)
    {:ok, buffered_stream} = Otis.Channel.BufferedStream.start_link(stream_id, stream_config, audio_stream)

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
      {:ok, ^p} = Otis.AudioStream.frame(buffered_stream)
    end
    :stopped = Otis.AudioStream.frame(buffered_stream)
  end
end

