defmodule Otis.Test.TestSource do
  defstruct [
    :id,
    loaded: false,
  ]
  def new do
    %__MODULE__{id: Otis.uuid}
  end
end

defimpl Otis.Source, for: Otis.Test.TestSource do
  def id(source) do
    source.id
  end

  def type(_source) do
    Otis.Test.TestSource
  end

  def open!(_source, _packet_size_bytes) do
    # noop
  end

  def close(_source, _stream) do
    # noop
  end

  def audio_type(_track) do
    # noop
  end

  def metadata(_track) do
    # noop
  end
end

defimpl Otis.Source.Origin, for: Otis.Test.TestSource do
  def load!(source) do
    %Otis.Test.TestSource{ source | loaded: true }
  end
end

defmodule Otis.Persistence.SourceTest do
  use   ExUnit.Case
  alias Otis.Test.TestSource
  alias Otis.State.Source

  setup_all do
    on_exit fn ->
      Otis.State.Source.delete_all
      Otis.State.Zone.delete_all
    end
    {:ok, zone_id: Otis.uuid }
  end

  setup context do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach

    zone_record = Otis.State.Zone.create!(context.zone_id, "Test Zone")
    {:ok, zone} = Otis.Zones.start(zone_record)
    {:ok, source_list} = Otis.Zone.source_list(zone)

    on_exit fn ->
      Otis.Zones.destroy!(context.zone_id)
    end

    {:ok,
      zone: %Otis.Zone{pid: zone, id: zone_record.id},
      source_list: source_list,
      zone_record: zone_record,
    }
  end

  test "adding a source to a list persists to the db", context do
    Otis.SourceList.append_source(context.source_list, TestSource.new)
    {:ok, [entry]} = Otis.SourceList.list(context.source_list)
    {source_id, source} = entry
    assert_receive {:new_source_created, _}
    [record] = Otis.State.Source.all
    assert record.id == source_id
    assert record.zone_id == context.zone.id
    assert record.source_type == to_string(TestSource)
    assert record.source_id == source.id
  end

  test "adding multiple sources persists to the db", context do
    Otis.SourceList.append_sources(context.source_list, [TestSource.new, TestSource.new])
    {:ok, [entry1, entry2]} = Otis.SourceList.list(context.source_list)
    {source_id1, source1} = entry1
    {source_id2, source2} = entry2
    assert_receive {:new_source_created, _}
    assert_receive {:new_source_created, _}
    [record1, record2] = Otis.State.Source.all
    assert record1.id == source_id1
    assert record1.source_id == source1.id
    assert record1.zone_id == context.zone.id
    assert record1.source_type == to_string(TestSource)
    assert record1.position == 0

    assert record2.id == source_id2
    assert record2.source_id == source2.id
    assert record2.zone_id == context.zone.id
    assert record2.source_type == to_string(TestSource)
    assert record2.position == 1
  end

  test "you can lookup sources for a zone", context do
    Otis.SourceList.append_sources(context.source_list, [TestSource.new, TestSource.new])
    assert_receive {:new_source_created, _}
    assert_receive {:new_source_created, _}
    {:ok, [entry1, entry2]} = Otis.SourceList.list(context.source_list)
    {source_id1, source1} = entry1
    {source_id2, source2} = entry2
    [record1, record2] = Source.for_zone(context.zone)

    assert record1.id == source_id1
    assert record1.source_id == source1.id
    assert record1.zone_id == context.zone.id
    assert record1.source_type == to_string(TestSource)
    assert record1.position == 0

    assert record2.id == source_id2
    assert record2.source_id == source2.id
    assert record2.zone_id == context.zone.id
    assert record2.source_type == to_string(TestSource)
    assert record2.position == 1
  end

  test "a source played event deletes the corresponding db record", context do
    Otis.SourceList.append_sources(context.source_list, [TestSource.new, TestSource.new])
    {:ok, [entry1, entry2]} = Otis.SourceList.list(context.source_list)
    {source_id1, _source1} = entry1
    {source_id2, source2} = entry2
    Otis.State.Events.notify({:source_changed, context.zone.id, source_id1, source_id2})
    assert_receive {:old_source_removed, ^source_id1}
    [record2] = Otis.State.Source.all
    assert record2.id == source_id2
    assert record2.source_id == source2.id
    assert record2.zone_id == context.zone.id
    assert record2.source_type == to_string(TestSource)
  end

  test "a final source played event leaves the source list empty", context do
    Otis.SourceList.append_sources(context.source_list, [TestSource.new, TestSource.new])
    {:ok, [entry1, entry2]} = Otis.SourceList.list(context.source_list)
    {source_id1, _source1} = entry1
    {source_id2, _source2} = entry2
    Otis.State.Events.notify({:source_changed, context.zone.id, source_id1, source_id2})
    assert_receive {:old_source_removed, ^source_id1}
    Otis.State.Events.notify({:source_changed, context.zone.id, source_id2, nil})
    assert_receive {:old_source_removed, ^source_id2}
    [] = Otis.State.Source.all
  end

  test "a source played event updates the db positions", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    Otis.SourceList.append_sources(context.source_list, sources)
    assert_receive {:new_source_created, _}
    {:ok, [{id1, _source1}, {id2, _source2}, {id3, _source3}, {id4, _source4}]} = Otis.SourceList.list(context.source_list)
    ids = [id1, id2, id3, id4]
    positions = ids |> Enum.map(fn(id) -> Otis.State.Source.find(id) end) |> Enum.map(fn(rec) -> rec.position end)
    assert [0, 1, 2, 3] == positions
    Otis.State.Events.notify({:source_changed, context.zone.id, id1, id2})
    assert_receive {:old_source_removed, ^id1}
    ids = [id2, id3, id4]
    positions = ids |> Enum.map(fn(id) -> Otis.State.Source.find(id) end) |> Enum.map(fn(rec) -> rec.position end)
    assert [0, 1, 2] == positions
  end

  test "a skip deletes every unplayed source from the db", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    Otis.SourceList.append_sources(context.source_list, sources)
    assert_receive {:new_source_created, _}, 200
    {:ok, entries} = Otis.SourceList.list(context.source_list)
    ids = Enum.map(entries, fn({id, _}) -> id end)
    skip_to = Enum.at(ids, -2)
    skipped_ids = Enum.take_while(ids, fn(id) -> id != skip_to end)
    kept_ids = Enum.drop_while(ids, fn(id) -> id != skip_to end)
    {:ok, 2} = Otis.SourceList.skip(context.source_list, skip_to)
    zone_id = context.zone.id
    assert_receive {:sources_skipped, ^zone_id, ^skipped_ids}
    assert [nil, nil, nil] = skipped_ids |> Enum.map(&Otis.State.Source.find/1)
    positions = kept_ids |> Enum.map(fn(id) -> Otis.State.Source.find(id) end) |> Enum.map(fn(rec) -> rec.position end)
    assert [0, 1] == positions
  end

  test "restores source lists from db", context do
    sources = Enum.map [TestSource.new, TestSource.new], &Otis.SourceList.source_with_id/1
    sources |> Enum.with_index |> Enum.each(fn({source, position}) ->
      Otis.State.Events.notify {:new_source, context.zone.id, position, source}
    end)
    assert_receive {:new_source_created, _}
    assert_receive {:new_source_created, _}
    {:ok, []} = Otis.SourceList.list(context.source_list)
    Otis.Startup.restore_source_lists(Otis.State, Otis.Zones)
    # Otis.SourceList.append_sources(context.source_list, [TestSource.new, TestSource.new])
    [{id1, source1}, {id2, source2}] = sources
    {:ok, [{ed1, entry1}, {ed2, entry2}]} = Otis.SourceList.list(context.source_list)
    assert id1 == ed1
    assert id2 == ed2
    assert %TestSource{source1 | loaded: true} == entry1
    assert %TestSource{source2 | loaded: true} == entry2
  end
end
