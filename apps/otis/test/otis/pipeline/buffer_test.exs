defmodule Test.Otis.Pipeline.Buffer do
  use ExUnit.Case

  alias Otis.State.Rendition
  alias Test.CycleSource
  alias Otis.Pipeline.Producer

  @channel_id Otis.uuid()

  setup_all do
    CycleSource.start_table()
  end

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    _channel = @channel_id |> Otis.State.Channel.create!("Test Channel")

    config = %Otis.Pipeline.Config{
      packet_size: 100,
      packet_duration_ms: 20,
      buffer_packets: 10,
      transcoder: Test.PassthroughTranscoder
    }

    {:ok, config: config}
  end

  test "streaming from source", context do
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>
    ]

    rendition = CycleSource.rendition!(@channel_id, d, -1)
    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition.id, context.config)

    {:ok, packet} = Producer.next(buffer)
    %Otis.Packet{} = packet
    assert packet.rendition_id == rendition.id
    assert packet.source_index == 0
    assert packet.offset_ms == 0
    assert packet.duration_ms == 20
    assert packet.packet_size == 100
    assert byte_size(packet.data) == 100

    assert packet.data ==
             <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97fb813a98e8f69a76420fe0e880b2aacfae50a">>

    {:ok, packet} = Producer.next(buffer)
    assert packet.rendition_id == rendition.id
    assert packet.source_index == 1
    assert packet.offset_ms == 20
    assert packet.duration_ms == 20
    assert packet.packet_size == 100
    assert byte_size(packet.data) == 100

    assert packet.data ==
             <<"c20c0f7e5a74b8c36d2544bc6f82a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf640043650ab93fd">>

    {:ok, packet} = Producer.next(buffer)
    assert packet.rendition_id == rendition.id
    assert packet.source_index == 2
    assert packet.offset_ms == 40
    assert byte_size(packet.data) == 100

    assert packet.data ==
             <<"ebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97fb813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e">>
  end

  test "streaming short source", context do
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>
    ]

    rendition = CycleSource.rendition!(@channel_id, d, 1)

    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition.id, context.config)
    {:done, packet} = Producer.next(buffer)
    %Otis.Packet{} = packet
    assert packet.rendition_id == rendition.id
    assert packet.source_index == 0
    assert packet.offset_ms == 0
    assert packet.duration_ms == 20
    assert packet.packet_size == 100
    assert byte_size(packet.data) == 100

    assert packet.data ==
             <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97fb813a98e8f69a76420fe0e880b2aacfae50a">>

    {:done, packet} = Producer.next(buffer)
    assert packet.rendition_id == rendition.id
    assert packet.source_index == 1
    assert packet.offset_ms == 20
    assert packet.duration_ms == 20
    assert packet.packet_size == 100
    assert byte_size(packet.data) == 100

    assert packet.data ==
             <<"c20c0f7e5a74b8c36d2544bc6f82a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436",
               0, 0, 0, 0, 0, 0, 0, 0>>

    pid = GenServer.whereis(buffer)
    Process.monitor(pid)
    :done = Producer.next(buffer)
    assert_receive {:DOWN, _ref, :process, ^pid, {:shutdown, :normal}}
  end

  test "source size multiple of packet size", context do
    config = %Otis.Pipeline.Config{context.config | packet_size: 64}

    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>
    ]

    rendition = CycleSource.rendition!(@channel_id, d, 1)

    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition.id, config)
    pid = GenServer.whereis(buffer)
    Process.monitor(pid)

    {:done, packet} = Producer.next(buffer)
    %Otis.Packet{} = packet
    assert packet.rendition_id == rendition.id
    assert packet.source_index == 0
    assert packet.offset_ms == 0
    assert packet.duration_ms == 20
    assert packet.packet_size == 64
    assert byte_size(packet.data) == 64
    assert packet.data == <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>

    {:done, packet} = Producer.next(buffer)
    assert packet.rendition_id == rendition.id
    assert packet.source_index == 1
    assert packet.offset_ms == 20
    assert packet.duration_ms == 20
    assert packet.packet_size == 64
    assert byte_size(packet.data) == 64
    assert packet.data == <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>
    assert :done == Producer.next(buffer)

    assert_receive {:DOWN, _, :process, ^pid, {:shutdown, :normal}}
  end

  test "stopping buffer", context do
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>
    ]

    rendition = CycleSource.rendition!(@channel_id, d, 1)
    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition.id, context.config)
    pid = GenServer.whereis(buffer)
    assert is_pid(pid) == true
    Process.monitor(pid)
    Producer.stop(buffer)
    assert_receive {:DOWN, _, :process, ^pid, {:shutdown, :normal}}
    pid = GenServer.whereis(buffer)
    assert is_nil(pid) == true
  end

  test "partially played renditions", context do
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>
    ]

    rendition = CycleSource.rendition!(@channel_id, d, 1)
    rendition = rendition |> Rendition.update(playback_duration: 2000, playback_position: 1000)
    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition.id, context.config)
    {:done, packet} = Producer.next(buffer)
    assert packet.offset_ms == 1000
  end

  test "pausing file buffers returns :ok", context do
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>
    ]

    rendition = CycleSource.rendition!(@channel_id, d, 1)
    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition.id, context.config)
    {:done, _packet} = Producer.next(buffer)
    assert :ok == Producer.pause(buffer)
  end

  test "pausing live buffers returns :stop", context do
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>
    ]

    rendition = CycleSource.rendition!(@channel_id, d, 1, :live)
    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition.id, context.config)
    {:done, _packet} = Producer.next(buffer)
    assert :stop == Producer.pause(buffer)
  end

  test "buffer sends file source duration", context do
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>
    ]

    rendition = CycleSource.rendition!(@channel_id, d, 1)
    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition.id, context.config)
    {:done, packet} = Producer.next(buffer)
    assert packet.source_duration == 100_000
  end
end
