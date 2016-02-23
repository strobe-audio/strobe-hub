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
      Otis.State.Zone.delete_all
      Otis.State.Source.delete_all
    end
    Otis.State.Zone.delete_all
    Otis.State.Source.delete_all
    zone_record = Otis.State.Zone.create!(Otis.uuid, "Test Zone")
    {:ok, zone} = Otis.Zones.start(zone_record)
    {:ok, source_list} = Otis.Zone.source_list(zone)
    {:ok,
      zone: %Otis.Zone{pid: zone, id: zone_record.id},
      zone_record: zone_record,
      source_list: source_list,
    }
  end

  setup context do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    pid = self
    :ok = Otis.State.Events.add_handler(MessagingHandler, pid)
    Otis.SourceList.clear(context.source_list)
    on_exit fn ->
      Otis.State.Events.remove_handler(MessagingHandler, self)
      assert_receive :remove_messaging_handler, 100
    end
    :ok
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
