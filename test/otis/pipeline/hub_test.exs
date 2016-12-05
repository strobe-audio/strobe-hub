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
    :ets.insert(table, {id, source.pid})
    %Rendition{id: Otis.uuid(), channel_id: @channel_id, source_type: Source.type(source) |> to_string, source_id: {table, id}, playback_duration: 1000, playback_position: 0, position: 0}

  end

  test "source lookup", context do
    source = CycleSource.new([1, 2, 3], -1)
    r1 = rendition(source, context.table)
    s = Rendition.source(r1)
    assert {:ok, 1} == Producer.next(s)
    assert {:ok, 2} == Producer.next(s)
    assert {:ok, 3} == Producer.next(s)
  end

  test "stream", context do
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


    hub = Hub.new("hub", pl, 64, 20, Test.PassthroughTranscoder)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
    IO.inspect Producer.next(hub)
  end
end
