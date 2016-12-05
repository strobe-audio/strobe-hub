defmodule Test.Otis.Pipeline.Buffer do
  use ExUnit.Case

  alias Otis.State.Rendition
  alias Otis.Library.Source
  alias Test.CycleSource
  alias Otis.Pipeline.Producer

  @table :cycle_sources

  setup do
    table = :ets.new(@table, [:set, :public, :named_table])
    {:ok, table: table}
  end

  def rendition(id, source, table) do
    :ets.insert(table, {id, source})
    %Rendition{id: id, source_type: Source.type(source) |> to_string, source_id: Enum.join([@table, id], ":"), playback_duration: 1000, playback_position: 0, position: 0} |> Rendition.create!
  end

  test "streaming from source", context do
    config = %Otis.Pipeline.Config{
      packet_size: 100,
      packet_duration_ms: 20,
      buffer_packets: 10,
    }

    id = Otis.uuid()
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>,
    ]
    stream = CycleSource.new(d, -1)
    rendition = rendition(id, stream, context.table)
    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition, config, Test.PassthroughTranscoder)

    {:ok, packet} = Producer.next(buffer)
    %Otis.Packet{} = packet
    assert packet.source_id == id
    assert packet.source_index == 0
    assert packet.offset_ms == 0
    assert packet.duration_ms == 20
    assert packet.packet_size == 100
    assert byte_size(packet.data) == 100
    assert packet.data == <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97fb813a98e8f69a76420fe0e880b2aacfae50a">>
    {:ok, packet} = Producer.next(buffer)
    assert packet.source_id == id
    assert packet.source_index == 1
    assert packet.offset_ms == 20
    assert packet.duration_ms == 20
    assert packet.packet_size == 100
    assert byte_size(packet.data) == 100
    assert packet.data == <<"c20c0f7e5a74b8c36d2544bc6f82a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf640043650ab93fd">>
    {:ok, packet} = Producer.next(buffer)
    assert packet.source_id == id
    assert packet.source_index == 2
    assert packet.offset_ms == 40
    assert byte_size(packet.data) == 100
    assert packet.data == <<"ebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97fb813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e">>
  end

  test "streaming short source", context do
    config = %Otis.Pipeline.Config{
      packet_size: 100,
      packet_duration_ms: 20,
      buffer_packets: 10,
    }
    id = Otis.uuid()
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>,
    ]
    stream = CycleSource.new(d, 1)
    # {:ok, buffer} = Buffer.start_link(id, stream, 100, 20, 10)
    rendition = rendition(id, stream, context.table)
    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition, config, Test.PassthroughTranscoder)
    {:done, packet} = Producer.next(buffer)
    %Otis.Packet{} = packet
    assert packet.source_id == id
    assert packet.source_index == 0
    assert packet.offset_ms == 0
    assert packet.duration_ms == 20
    assert packet.packet_size == 100
    assert byte_size(packet.data) == 100
    assert packet.data == <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97fb813a98e8f69a76420fe0e880b2aacfae50a">>
    {:done, packet} = Producer.next(buffer)
    assert packet.source_id == id
    assert packet.source_index == 1
    assert packet.offset_ms == 20
    assert packet.duration_ms == 20
    assert packet.packet_size == 100
    assert byte_size(packet.data) == 100
    assert packet.data == <<"c20c0f7e5a74b8c36d2544bc6f82a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436",0,0,0,0,0,0,0,0>>
    :done = Producer.next(buffer)
    pid = GenServer.whereis(buffer)
    assert nil == pid
  end

  test "source size multiple of packet size", context do
    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
    }
    id = Otis.uuid()
    d = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
    ]
    stream = CycleSource.new(d, 1)
    rendition = rendition(id, stream, context.table)
    {:ok, buffer} = Otis.Pipeline.Streams.start_stream(rendition, config, Test.PassthroughTranscoder)
    {:done, packet} = Producer.next(buffer)
    %Otis.Packet{} = packet
    assert packet.source_id == id
    assert packet.source_index == 0
    assert packet.offset_ms == 0
    assert packet.duration_ms == 20
    assert packet.packet_size == 64
    assert byte_size(packet.data) == 64
    assert packet.data == <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>
    {:done, packet} = Producer.next(buffer)
    assert packet.source_id == id
    assert packet.source_index == 1
    assert packet.offset_ms == 20
    assert packet.duration_ms == 20
    assert packet.packet_size == 64
    assert byte_size(packet.data) == 64
    assert packet.data == <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>
    assert :done == Producer.next(buffer)
    pid = GenServer.whereis(buffer)
    assert nil == pid
  end
end
