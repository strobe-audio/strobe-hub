defmodule Test.Otis.Pipeline.Hub do
  use ExUnit.Case

  alias Otis.State.Rendition
  alias Otis.Library.Source
  alias Otis.Pipeline.Playlist
  alias Otis.Pipeline.Producer
  alias Otis.Pipeline.Hub
  alias Test.CycleSource

  @dir Path.expand("../../fixtures", __DIR__)
  @channel_id Otis.uuid()
  setup do
    table = :ets.new(:cycle_sources, [:set, :public])
    {:ok, table: table}
  end

  def test_file(filename), do: Path.join(@dir, filename)

  def rendition(source, table) do
    id = Otis.uuid()
    :ets.insert(table, {id, source})
    %Rendition{id: Otis.uuid(), channel_id: @channel_id, source_type: Source.type(source) |> to_string, source_id: {table, id}, playback_duration: 1000, playback_position: 0, position: 0}

  end

  test "source lookup", context do
    source = CycleSource.new([1, 2, 3], -1)
    r1 = rendition(source, context.table)
    s = Rendition.source(r1)
    %CycleSource{} = s
    assert {:ok, 1} == Producer.next(s)
    assert {:ok, 2} == Producer.next(s)
    assert {:ok, 3} == Producer.next(s)
  end

  test "streaming", context do
    s1 = CycleSource.new([<<"1">>], 1024)
    s2 = CycleSource.new([<<"2">>], 1024)
    s3 = CycleSource.new([<<"3">>], 1024)
    r1 = rendition(s1, context.table)
    r2 = rendition(s2, context.table)
    r3 = rendition(s3, context.table)
    renditions = [r1, r2, r3]
    {:ok, pl} = Playlist.start_link(@channel_id)
    Playlist.replace(pl, renditions)
    {:ok, _} = Playlist.list(pl) # make sure the playlist is synced


    config = %Otis.Pipeline.Config{
      packet_size: 64,
      packet_duration_ms: 20,
      buffer_packets: 10,
    }
    {:ok, hub} = Hub.start_link(pl, config, Test.PassthroughTranscoder)
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("1", 64)
      assert p.source_id == r1.id
    end
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("2", 64)
      assert p.source_id == r2.id
    end
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("3", 64)
      assert p.source_id == r3.id
    end
    assert :done == Producer.next(hub)
    assert :done == Producer.next(hub)

    # Now make sure that the hub starts playing again if we add a source
    s4 = CycleSource.new([<<"4">>], 1024)
    r4 = rendition(s4, context.table)
    Playlist.replace(pl, [r4])
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("4", 64)
      assert p.source_id == r4.id
    end

    assert :done == Producer.next(hub)

    # Now make sure that the hub starts playing again if we add a source
    s5 = CycleSource.new([<<"5">>], 1024)
    r5 = rendition(s5, context.table)
    s6 = CycleSource.new([<<"6">>], 1024)
    r6 = rendition(s6, context.table)
    Playlist.replace(pl, [r5, r6])
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("5", 64)
      assert p.source_id == r5.id
    end
    Enum.each 0..15, fn(_) ->
      {:ok, p} = Producer.next(hub)
      assert p.data == String.duplicate("6", 64)
      assert p.source_id == r6.id
    end
    assert :done == Producer.next(hub)
  end
end
