defmodule Test.Otis.Pipeline.Hub do
  use ExUnit.Case

  alias Otis.Pipeline.Playlist
  alias Otis.Pipeline.Producer
  alias Otis.Pipeline.Hub
  alias Test.CycleSource

  @dir Path.expand("../../fixtures", __DIR__)
  @channel_id Otis.uuid()

  setup_all do
    CycleSource.start_table()
  end

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    channel = @channel_id |> Otis.State.Channel.create!("Test Channel")
    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
      transcoder: Test.PassthroughTranscoder,
    }
    {:ok, config: config, channel: channel}
  end

  def test_file(filename), do: Path.join(@dir, filename)

  def rendition(_source, _table) do
    # :ets.insert(table, {source.id, source})
    # %Rendition{id: Otis.uuid(), channel_id: @channel_id, source_type: Source.type(source) |> to_string, source_id: Enum.join([@table, source.id], ":"), playback_duration: 1000, playback_position: 0, position: 0} |> Rendition.create!
  end

  test "initialize with empty playlist", context do
    {:ok, pl} = Playlist.start_link(@channel_id)
    {:ok, hub} = Hub.start_link(pl, context.config)

    r1 = CycleSource.rendition!(@channel_id, [<<"1">>], 1024)
    renditions = [r1]
    Playlist.replace(pl, renditions)
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("1", 64)
      assert p.rendition_id == r1.id
    end
  end

  test "streaming", context do
    r1 = CycleSource.rendition!(@channel_id, [<<"1">>], 1024)
    r2 = CycleSource.rendition!(@channel_id, [<<"2">>], 1024)
    r3 = CycleSource.rendition!(@channel_id, [<<"3">>], 1024)

    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)
    {:ok, _} = Playlist.list(pl) # make sure the playlist is synced


    {:ok, hub} = Hub.start_link(pl, context.config)
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("1", 64)
      assert p.rendition_id == r1.id
    end
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("2", 64)
      assert p.rendition_id == r2.id
    end
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("3", 64)
      assert p.rendition_id == r3.id
    end
    assert :done == Producer.next(hub)
    assert :done == Producer.next(hub)

    # Now make sure that the hub starts playing again if we add a source
    r4 = CycleSource.rendition!(@channel_id, [<<"4">>], 1024)
    Playlist.replace(pl, [r4])
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("4", 64)
      assert p.rendition_id == r4.id
    end

    assert :done == Producer.next(hub)

    # Now make sure that the hub starts playing again if we add a source
    r5 = CycleSource.rendition!(@channel_id, [<<"5">>], 1024)
    r6 = CycleSource.rendition!(@channel_id, [<<"6">>], 1024)
    Playlist.replace(pl, [r5, r6])
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("5", 64)
      assert p.rendition_id == r5.id
    end
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("6", 64)
      assert p.rendition_id == r6.id
    end
    assert :done == Producer.next(hub)
  end

  test "skipping", context do
    r1 = CycleSource.rendition!(@channel_id, [<<"1">>], 1024)
    r2 = CycleSource.rendition!(@channel_id, [<<"2">>], 1024)
    r3 = CycleSource.rendition!(@channel_id, [<<"3">>], 1024)

    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)
    {:ok, _} = Playlist.list(pl) # make sure the playlist is synced

    {:ok, hub} = Hub.start_link(pl, context.config)
    {:ok, p} = Producer.next(hub)
    assert p.data == String.duplicate("1", 64)
    assert p.rendition_id == r1.id
    assert p.source_index == 0

    {:ok, p} = Producer.next(hub)
    assert p.data == String.duplicate("1", 64)
    assert p.rendition_id == r1.id
    assert p.source_index == 1

    Hub.skip(hub, r2.id)

    {:ok, p} = Producer.next(hub)
    assert p.data == String.duplicate("2", 64)
    assert p.rendition_id == r2.id
    assert p.source_index == 0

    {:ok, p} = Producer.next(hub)
    assert p.data == String.duplicate("2", 64)
    assert p.rendition_id == r2.id
    assert p.source_index == 1
  end

  test "pausing/resuming file sources", context do
    c1 = [d1, d2, _] = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>,
    ]
    r1 = CycleSource.rendition!(@channel_id, c1, 1024)
    renditions = [r1]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)
    {:ok, _} = Playlist.list(pl) # make sure the playlist is synced

    {:ok, hub} = Hub.start_link(pl, context.config)
    {:ok, p} = Producer.next(hub)
    assert p.data == d1

    c = Otis.Pipeline.Streams.streams() |> length()
    assert :ok == Hub.pause(hub)

    assert length(Otis.Pipeline.Streams.streams()) == c
    {:ok, p} = Producer.next(hub)
    assert p.data == d2
  end

  test "pausing & resuming live sources", context do
    c1 = [d1 | _] = [
      <<"50ab93fdebd6c2c3da8fb2abd8e80e65738f1f3a9616d615f5249fe3cdf7c97f">>,
      <<"b813a98e8f69a76420fe0e880b2aacfae50ac20c0f7e5a74b8c36d2544bc6f82">>,
      <<"a854348945279178e8468312448caef2e49e3466a55a3bdce6844dfaf6400436">>,
    ]
    r1 = CycleSource.rendition!(@channel_id, c1, 1024, :live)

    renditions = [r1]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)
    {:ok, _} = Playlist.list(pl) # make sure the playlist is synced

    {:ok, hub} = Hub.start_link(pl, context.config)
    {:ok, p} = Producer.next(hub)
    assert p.data == d1

    c = Otis.Pipeline.Streams.streams() |> length()
    resp = Producer.pause(hub)
    assert resp == :stop
    assert length(Otis.Pipeline.Streams.streams()) == c - 1
    {:ok, p} = Producer.next(hub)
    assert p.data == d1
  end
end
