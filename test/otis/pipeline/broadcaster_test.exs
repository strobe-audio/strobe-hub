defmodule Test.Otis.Pipeline.Broadcaster do
  use ExUnit.Case

  import MockReceiver

  alias Otis.Packet
  alias Otis.Receiver
  alias Otis.Library.Source
  alias Otis.Pipeline.Broadcaster
  alias Otis.Pipeline.Hub
  alias Otis.Pipeline.Playlist
  alias Otis.State.Rendition
  alias Test.CycleSource

  @table :cycle_sources
  @channel_id Otis.uuid()
  @receiver_latency 2222

  def rendition(source) do
    :ets.insert(@table, {source.id, source})
    %Rendition{
      id: Otis.uuid(),
      channel_id: @channel_id,
      source_type: Source.type(source) |> to_string,
      source_id: Test.CycleSource.source_id(@table, source.id),
      playback_duration: 1000,
      playback_position: 0,
      position: 0,
    } |> Rendition.create!
  end

  setup do
    MessagingHandler.attach()
    _table = :ets.new(@table, [:set, :public, :named_table])

    channel_id = Otis.uuid
    id1 = Otis.uuid
    id2 = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id1)
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id2)
    mock1 = connect!(id1, 1234)
    mock2 = connect!(id2, @receiver_latency)
    assert_receive {:receiver_connected, [^id1, _]}
    assert_receive {:receiver_connected, [^id2, _]}
    receivers = Otis.Receivers.Sets.lookup(channel_id)
    r1 = Enum.find(receivers, fn(r) -> r.id == id1 end)
    r2 = Enum.find(receivers, fn(r) -> r.id == id2 end)
    {:ok, channel: channel_record, channel_id: channel_id, receivers: [r1, r2], mocks: [mock1, mock2]}
  end

  test "broadcaster does a flood send of receivers on start", context do
    s1 = CycleSource.new([<<"1">>], 1024)
    s2 = CycleSource.new([<<"2">>], 1024)
    s3 = CycleSource.new([<<"3">>], 1024)
    r1 = rendition(s1)
    r2 = rendition(s2)
    r3 = rendition(s3)

    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000
    packet_time = fn(n) ->
      time + @receiver_latency  + (config.base_latency_ms * 1000) + (n * config.packet_duration_ms * 1_000)
    end
    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    [m1, m2] = context.mocks
    :pong = GenServer.call(bc, :ping)
    Enum.each(0..4, fn(n) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("1", 64)
        assert packet.timestamp == packet_time.(n)
        assert packet.packet_number == n
      end)
    end)
  end

  test "clock tick sends next packet", context do
    s1 = CycleSource.new([<<"1">>], 1024)
    s2 = CycleSource.new([<<"2">>], 1024)
    s3 = CycleSource.new([<<"3">>], 1024)
    r1 = rendition(s1)
    r2 = rendition(s2)
    r3 = rendition(s3)

    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    packet_time = fn(n) ->
      time + @receiver_latency  + (config.base_latency_ms * 1000) + (n * config.packet_duration_ms * 1_000)
    end

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    [m1, m2] = context.mocks
    :pong = GenServer.call(bc, :ping)
    Enum.each(0..4, fn(n) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("1", 64)
        assert packet.timestamp == packet_time.(n)
        assert packet.packet_number == n
      end)
    end)

    Enum.each(5..15, fn(n) ->
      GenServer.call(clock, {:tick, time})
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("1", 64)
        assert packet.timestamp == packet_time.(n)
        assert packet.packet_number == n
      end)
    end)
    Enum.each(16..31, fn(n) ->
      GenServer.call(clock, {:tick, time})
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("2", 64)
        assert packet.timestamp == packet_time.(n)
        assert packet.packet_number == n
      end)
    end)
    Enum.each(32..47, fn(n) ->
      GenServer.call(clock, {:tick, time})
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("3", 64)
        assert packet.timestamp == packet_time.(n)
        assert packet.packet_number == n
      end)
    end)
  end

  test "late clock ticks send enought packets to catch up receiver", context do
    s1 = CycleSource.new([<<"1">>], 1024)
    s2 = CycleSource.new([<<"2">>], 1024)
    s3 = CycleSource.new([<<"3">>], 1024)
    r1 = rendition(s1)
    r2 = rendition(s2)
    r3 = rendition(s3)

    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    packet_time = fn(n) ->
      time + @receiver_latency  + (config.base_latency_ms * 1000) + (n * config.packet_duration_ms * 1_000)
    end
    tick_time = fn(n) ->
      time + (n * config.packet_duration_ms * 1_000)
    end

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    [m1, m2] = context.mocks
    :pong = GenServer.call(bc, :ping)
    Enum.each(0..4, fn(n) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("1", 64)
        assert packet.timestamp == packet_time.(n)
        assert packet.packet_number == n
      end)
    end)

    GenServer.call(clock, {:tick, tick_time.(10)})

    Enum.each(5..14, fn(n) ->
      IO.inspect [:test, n]
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("1", 64)
        assert packet.timestamp == packet_time.(n)
        assert packet.packet_number == n
      end)
    end)

    GenServer.call(clock, {:tick, tick_time.(10)})
    :pong = GenServer.call(bc, :ping)
    Enum.each([m1, m2], fn(m) ->
      {:error, :timeout} = data_recv_raw(m)
    end)
  end

  test "new receivers get buffer packets", context do
    s1 = CycleSource.new([<<"1">>], 1024)
    s2 = CycleSource.new([<<"2">>], 1024)
    s3 = CycleSource.new([<<"3">>], 1024)
    r1 = rendition(s1)
    r2 = rendition(s2)
    r3 = rendition(s3)

    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    packet_time = fn(n) ->
      time + @receiver_latency + (config.base_latency_ms * 1000) + (n * config.packet_duration_ms * 1_000)
    end

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    :pong = GenServer.call(bc, :ping)
    [m1, m2] = context.mocks
    Enum.each(0..4, fn(_) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)
    Enum.each(5..10, fn(n) ->
      GenServer.call(clock, {:tick, time + ((n - 4) * config.packet_duration_ms * 1000)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)

    time = packet_time.(4)
    GenServer.call(clock, {:set_time, time})

    id3 = Otis.uuid
    Otis.State.Receiver.create!(context.channel, id: id3)
    m3 = connect!(id3, 2000)
    assert_receive {:receiver_connected, [^id3, _]}

    Enum.each(0..4, fn(n) ->
      {:ok, data} = data_recv_raw(m3)
      packet = Packet.unmarshal(data)
      assert packet.packet_number == (n+6)
      assert packet.timestamp == packet_time.(n+6)
    end)
  end

  test "rendition progress events", context do
    s1 = CycleSource.new([<<"1">>], 1024)
    s2 = CycleSource.new([<<"2">>], 1024)
    s3 = CycleSource.new([<<"3">>], 1024)
    r1 = rendition(s1)
    r2 = rendition(s2)
    r3 = rendition(s3)

    r1id = r1.id
    r2id = r2.id
    channel_id = context.channel_id

    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    # packet_time = fn(n) ->
    #   time + @receiver_latency + (config.base_latency_ms * 1000) + (n * config.packet_duration_ms * 1_000)
    # end
    tick_time = fn(n) ->
      time + (n * config.packet_duration_ms * 1_000)
    end

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    :pong = GenServer.call(bc, :ping)
    [m1, m2] = context.mocks
    Enum.each(0..4, fn(_) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)
    Enum.each(1..11, fn(n) ->
      GenServer.call(clock, {:tick, time + (n * config.packet_duration_ms * 1000)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("1", 64)
      end)
    end)

    Enum.each(5..15, fn(n) ->
      GenServer.call(clock, {:tick, tick_time.(n)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)
    Enum.each(16..31, fn(n) ->
      GenServer.call(clock, {:tick, tick_time.(n)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)
    Enum.each(0..15, fn(n) ->
      t = n*20
      assert_receive {:rendition_progress, [^channel_id, ^r1id, ^t, 20]}
    end)
    Enum.each(0..14, fn(n) ->
      t = n*20
      assert_receive {:rendition_progress, [^channel_id, ^r2id, ^t, 20]}
    end)
  end

  test "rendition change events", context do
    s1 = CycleSource.new([<<"1">>], 1024)
    s2 = CycleSource.new([<<"2">>], 1024)
    s3 = CycleSource.new([<<"3">>], 1024)
    r1 = rendition(s1)
    r2 = rendition(s2)
    r3 = rendition(s3)

    r1id = r1.id
    r2id = r2.id
    channel_id = context.channel_id

    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    tick_time = fn(n) ->
      time + (n * config.packet_duration_ms * 1_000)
    end

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    :pong = GenServer.call(bc, :ping)
    [m1, m2] = context.mocks
    Enum.each(0..4, fn(_) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)
    Enum.each(1..11, fn(n) ->
      GenServer.call(clock, {:tick, tick_time.(n)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("1", 64)
      end)
    end)
    assert_receive {:rendition_changed, [^channel_id, nil, ^r1id]}

    Enum.each(5..15, fn(n) ->
      GenServer.call(clock, {:tick, tick_time.(n)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)
    Enum.each(16..31, fn(n) ->
      GenServer.call(clock, {:tick, tick_time.(n)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)
    assert_receive {:rendition_changed, [^channel_id, ^r1id, ^r2id]}
  end

  test "rebuffer unplayed packets on resume", context do
    c = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>,
      <<"43580a18fcea3b0140b06f846bb0f1ab096e1b4606ce50beb436959b1357ca51">>,
      <<"74f1be954d80c416eb8d52e311a3563005f5e55a8c907c61ee42841db8376a14">>,
      <<"67e980ef42eaf6769e7ee2d0448992b436dd14d810e89a1964f1da7b39788729">>,
      <<"dfe361a4d493b336588c52155ba0862dad8e93918500218f9ad4842988146350">>,
      <<"baaeec3d7cd81021d61d7d6b1e3d8035cd02a2fb202ce46e45d87c92608fe7c7">>,
      <<"bd886cecd9a5fe76c61fbc9825d43a6821cdeafe65da464a0387606f20648f2d">>,
      <<"f48d7c8781d22dac4e0f4fe259c1d38c482910d44a54feccd543d5faec2019bf">>,
      <<"4f04ed880a8135752016f2571ac978920f52b01af678510e26634d2af45c2c5b">>,
      <<"6c8ce10ef9466f5ae2db72494424726c7c1369423cc6369b5b41c0c8cf03c07d">>,
      <<"6c7159ce46ce6aafe389b74eef651d480776cb28bd64c2ace6af2f8d0c325b36">>,
      <<"6abbfe5076735bcf01a1d804577e1429b8b90790e223d5422e62f9100bfc1874">>,
      <<"ff7b3b0600ad14fc37226997341e39ae0e0d46962aba4e61e5886c3a74e01f92">>,
      <<"a05840b11f6f31ee2ff801c36721b58e72704ce5823da13a13c283b3f469d6d9">>,
      <<"250faef208f92f6898994739c17141f57073ac7e14aeed826d16e5226b118013">>,
    ]
    s1 = CycleSource.new(c, 1)
    r1 = rendition(s1)

    [m1, m2] = context.mocks

    renditions = [r1]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    :pong = GenServer.call(bc, :ping)
    Enum.each(Enum.slice(c, 0..4), fn(d) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == d
      end)
    end)
    Broadcaster.pause(bc)

    Enum.each([m1, m2], fn(m) ->
      {:ok, data} = data_recv_raw(m)
      assert data == Receiver.stop_command()
    end)

    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    :pong = GenServer.call(bc, :ping)

    Enum.each(Enum.slice(c, 0..4), fn(d) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == d
      end)
    end)
  end

  test "skipping renditions", context do
    c1 = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>,
      <<"43580a18fcea3b0140b06f846bb0f1ab096e1b4606ce50beb436959b1357ca51">>,
      <<"74f1be954d80c416eb8d52e311a3563005f5e55a8c907c61ee42841db8376a14">>,
      <<"67e980ef42eaf6769e7ee2d0448992b436dd14d810e89a1964f1da7b39788729">>,
    ]
    c2 = [
      <<"dfe361a4d493b336588c52155ba0862dad8e93918500218f9ad4842988146350">>,
      <<"baaeec3d7cd81021d61d7d6b1e3d8035cd02a2fb202ce46e45d87c92608fe7c7">>,
      <<"bd886cecd9a5fe76c61fbc9825d43a6821cdeafe65da464a0387606f20648f2d">>,
      <<"f48d7c8781d22dac4e0f4fe259c1d38c482910d44a54feccd543d5faec2019bf">>,
      <<"4f04ed880a8135752016f2571ac978920f52b01af678510e26634d2af45c2c5b">>,
      <<"6c8ce10ef9466f5ae2db72494424726c7c1369423cc6369b5b41c0c8cf03c07d">>,
    ]
    c3 = [
      <<"6c7159ce46ce6aafe389b74eef651d480776cb28bd64c2ace6af2f8d0c325b36">>,
      <<"6abbfe5076735bcf01a1d804577e1429b8b90790e223d5422e62f9100bfc1874">>,
      <<"ff7b3b0600ad14fc37226997341e39ae0e0d46962aba4e61e5886c3a74e01f92">>,
      <<"a05840b11f6f31ee2ff801c36721b58e72704ce5823da13a13c283b3f469d6d9">>,
      <<"250faef208f92f6898994739c17141f57073ac7e14aeed826d16e5226b118013">>,
    ]
    s1 = CycleSource.new(c1, 1024)
    s2 = CycleSource.new(c2, 1024)
    s3 = CycleSource.new(c3, 1024)
    r1 = rendition(s1)
    r2 = rendition(s2)
    r3 = rendition(s3)

    renditions = [r1, r2, r3]
    channel_id = context.channel_id
    r1id = r1.id
    r3id = r3.id

    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    tick_time = fn(n) ->
      time + (n * config.packet_duration_ms * 1_000)
    end

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    :pong = GenServer.call(bc, :ping)
    [m1, m2] = context.mocks

    Enum.each(Enum.slice(c1, 0..4), fn(d) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == d
      end)
    end)
    Enum.each(5..16, fn(n) ->
      GenServer.call(clock, {:tick, tick_time.(n)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)
    assert_receive {:rendition_changed, [^channel_id, nil, ^r1id]}

    GenServer.call(clock, {:set_time, time})
    Broadcaster.skip(bc, r3.id)

    Enum.each(Enum.slice(c3, 0..4), fn(d) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == d
      end)
    end)
    Enum.each(5..16, fn(n) ->
      GenServer.call(clock, {:tick, tick_time.(n)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, _data} = data_recv_raw(m)
      end)
    end)
    assert_receive {:rendition_changed, [^channel_id, ^r1id, ^r3id]}
  end

  test "broadcaster stop/start events", context do
    s1 = CycleSource.new([<<"1">>], 1024)
    r1 = rendition(s1)
    [m1, m2] = context.mocks

    renditions = [r1]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    packet_time = fn(n) ->
      time + @receiver_latency  + (config.base_latency_ms * 1000) + (n * config.packet_duration_ms * 1_000)
    end
    tick_time = fn(n) ->
      time + (n * config.packet_duration_ms * 1_000)
    end

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    :pong = GenServer.call(bc, :ping)
    assert_receive :broadcaster_start

    Enum.each(0..4, fn(n) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("1", 64)
        assert packet.timestamp == packet_time.(n)
        assert packet.packet_number == n
      end)
    end)

    Enum.each(5..15, fn(n) ->
      GenServer.call(clock, {:tick, tick_time.(n - 4)})
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == String.duplicate("1", 64)
        assert packet.timestamp == packet_time.(n)
        assert packet.packet_number == n
      end)
    end)
    GenServer.call(clock, {:tick, packet_time.(14)})
    refute_receive :broadcaster_stop
    GenServer.call(clock, {:tick, packet_time.(16)})
    assert_receive :broadcaster_stop
    assert_receive {:clock, {:stop}}
  end

  # sources need to receive the pause, resume & close calls
  # live sources
  test "live sources", context do
    c1 = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>,
      <<"43580a18fcea3b0140b06f846bb0f1ab096e1b4606ce50beb436959b1357ca51">>,
      <<"74f1be954d80c416eb8d52e311a3563005f5e55a8c907c61ee42841db8376a14">>,
      <<"67e980ef42eaf6769e7ee2d0448992b436dd14d810e89a1964f1da7b39788729">>,
      <<"dfe361a4d493b336588c52155ba0862dad8e93918500218f9ad4842988146350">>,
      <<"baaeec3d7cd81021d61d7d6b1e3d8035cd02a2fb202ce46e45d87c92608fe7c7">>,
    ]
    c2 = [
      <<"bd886cecd9a5fe76c61fbc9825d43a6821cdeafe65da464a0387606f20648f2d">>,
      <<"f48d7c8781d22dac4e0f4fe259c1d38c482910d44a54feccd543d5faec2019bf">>,
      <<"4f04ed880a8135752016f2571ac978920f52b01af678510e26634d2af45c2c5b">>,
      <<"6c8ce10ef9466f5ae2db72494424726c7c1369423cc6369b5b41c0c8cf03c07d">>,
      <<"6c7159ce46ce6aafe389b74eef651d480776cb28bd64c2ace6af2f8d0c325b36">>,
      <<"6abbfe5076735bcf01a1d804577e1429b8b90790e223d5422e62f9100bfc1874">>,
      <<"ff7b3b0600ad14fc37226997341e39ae0e0d46962aba4e61e5886c3a74e01f92">>,
      <<"a05840b11f6f31ee2ff801c36721b58e72704ce5823da13a13c283b3f469d6d9">>,
      <<"250faef208f92f6898994739c17141f57073ac7e14aeed826d16e5226b118013">>,
    ]
    s1 = CycleSource.new(c1, 1, self(), :live)
    s2 = CycleSource.new(c2, 1, self(), :live)
    r1 = rendition(s1)

    [m1, m2] = context.mocks

    renditions = [r1]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    refute_receive {:source, :resume}
    :pong = GenServer.call(bc, :ping)
    Enum.each(Enum.slice(c1, 0..4), fn(d) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == d
      end)
    end)
    Broadcaster.pause(bc)
    assert_receive {:source, :pause}
    Enum.each([m1, m2], fn(m) ->
      {:ok, data} = data_recv_raw(m)
      assert data == Receiver.stop_command()
    end)

    :ets.insert(@table, {s1.id, s2})
    Broadcaster.start(bc)
    assert_receive {:clock, {:start, _, 20}}
    assert_receive {:source, :resume}

    Enum.each(Enum.slice(c2, 0..4), fn(d) ->
      Enum.each([m1, m2], fn(m) ->
        {:ok, data} = data_recv_raw(m)
        packet = Packet.unmarshal(data)
        assert packet.data == d
      end)
    end)
  end

  test "receiver events", context do
    s1 = CycleSource.new([<<"1">>], 1024)
    s2 = CycleSource.new([<<"2">>], 1024)
    s3 = CycleSource.new([<<"3">>], 1024)
    r1 = rendition(s1)
    r2 = rendition(s2)
    r3 = rendition(s3)

    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)

    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      receiver_buffer_ms: 100,
      base_latency_ms: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, hub} = Hub.start_link(pl, config)

    time = 1_000_000

    {:ok, clock} = Test.Otis.Pipeline.Clock.start_link(time)
    {:ok, bc} = Broadcaster.start_link(context.channel_id, self(), hub, clock, config)

    receiver_id = Otis.uuid()
    channel_id = context.channel_id
    _receiver_record = Otis.State.Receiver.create!(context.channel, id: receiver_id)

    Otis.Receivers.Sets.subscribe(:test, channel_id)
    mock = connect!(receiver_id, 1234)
    assert_receive {:receiver_joined, [^receiver_id, _]}
    :ok = :gen_tcp.close(mock.data_socket)
    assert_receive {:receiver_left, [^receiver_id, _]}
    # make sure the broadcaster has processed its message q
    :pong = GenServer.call(bc, :ping)
  end
end
