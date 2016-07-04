defmodule Otis.Persistence.SourceTest do
  use   ExUnit.Case
  alias Otis.Test.TestSource
  alias Otis.State.Source

  setup_all do
    on_exit fn ->
      Otis.State.Source.delete_all
      Otis.State.Channel.delete_all
    end
    {:ok, channel_id: Otis.uuid }
  end

  setup context do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach

    channel_record = Otis.State.Channel.create!(context.channel_id, "Test Channel")
    {:ok, channel} = Otis.Channels.start(channel_record)
    {:ok, source_list} = Otis.Channel.source_list(channel)

    on_exit fn ->
      Otis.Channels.destroy!(context.channel_id)
    end

    {:ok,
      channel: %Otis.Channel{pid: channel, id: channel_record.id},
      source_list: source_list,
      channel_record: channel_record,
    }
  end

  test "adding a source to a list persists to the db", context do
    Otis.SourceList.append(context.source_list, TestSource.new)
    {:ok, [entry]} = Otis.SourceList.list(context.source_list)
    {source_id, 0, source} = entry
    assert_receive {:new_source_created, _}
    [record] = Otis.State.Source.all
    assert record.id == source_id
    assert record.channel_id == context.channel.id
    assert record.source_type == to_string(TestSource)
    assert record.source_id == source.id
  end

  test "adding multiple sources persists to the db", context do
    Otis.SourceList.append(context.source_list, [TestSource.new, TestSource.new])
    {:ok, [entry1, entry2]} = Otis.SourceList.list(context.source_list)
    {source_id1, 0, source1} = entry1
    {source_id2, 0, source2} = entry2
    assert_receive {:new_source_created, _}
    assert_receive {:new_source_created, _}
    [record1, record2] = Otis.State.Source.all
    assert record1.id == source_id1
    assert record1.source_id == source1.id
    assert record1.channel_id == context.channel.id
    assert record1.source_type == to_string(TestSource)
    assert record1.position == 0

    assert record2.id == source_id2
    assert record2.source_id == source2.id
    assert record2.channel_id == context.channel.id
    assert record2.source_type == to_string(TestSource)
    assert record2.position == 1
  end

  test "you can lookup sources for a channel", context do
    Otis.SourceList.append(context.source_list, [TestSource.new, TestSource.new])
    assert_receive {:new_source_created, _}
    assert_receive {:new_source_created, _}
    {:ok, [entry1, entry2]} = Otis.SourceList.list(context.source_list)
    {source_id1, 0, source1} = entry1
    {source_id2, 0, source2} = entry2
    [record1, record2] = Source.for_channel(context.channel)

    assert record1.id == source_id1
    assert record1.source_id == source1.id
    assert record1.channel_id == context.channel.id
    assert record1.source_type == to_string(TestSource)
    assert record1.position == 0

    assert record2.id == source_id2
    assert record2.source_id == source2.id
    assert record2.channel_id == context.channel.id
    assert record2.source_type == to_string(TestSource)
    assert record2.position == 1
  end

  test "a source played event deletes the corresponding db record", context do
    Otis.SourceList.append(context.source_list, [TestSource.new, TestSource.new])
    {:ok, [entry1, entry2]} = Otis.SourceList.list(context.source_list)
    {source_id1, 0, _source1} = entry1
    {source_id2, 0, source2} = entry2
    Otis.State.Events.notify({:source_changed, context.channel.id, source_id1, source_id2})
    assert_receive {:old_source_removed, ^source_id1}
    [record2] = Otis.State.Source.all
    assert record2.id == source_id2
    assert record2.source_id == source2.id
    assert record2.channel_id == context.channel.id
    assert record2.source_type == to_string(TestSource)
  end

  test "a final source played event leaves the source list empty", context do
    Otis.SourceList.append(context.source_list, [TestSource.new, TestSource.new])
    {:ok, [entry1, entry2]} = Otis.SourceList.list(context.source_list)
    {source_id1, 0, _source1} = entry1
    {source_id2, 0, _source2} = entry2
    Otis.State.Events.notify({:source_changed, context.channel.id, source_id1, source_id2})
    assert_receive {:old_source_removed, ^source_id1}
    Otis.State.Events.notify({:source_changed, context.channel.id, source_id2, nil})
    assert_receive {:old_source_removed, ^source_id2}
    [] = Otis.State.Source.all
  end

  test "a source played event updates the db positions", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    Otis.SourceList.append(context.source_list, sources)
    assert_receive {:new_source_created, _}
    {:ok, [{id1, 0, _source1}, {id2, 0, _source2}, {id3, 0, _source3}, {id4, 0, _source4}]} = Otis.SourceList.list(context.source_list)
    ids = [id1, id2, id3, id4]
    positions = ids |> Enum.map(fn(id) -> Otis.State.Source.find(id) end) |> Enum.map(fn(rec) -> rec.position end)
    assert [0, 1, 2, 3] == positions
    Otis.State.Events.notify({:source_changed, context.channel.id, id1, id2})
    assert_receive {:old_source_removed, ^id1}
    ids = [id2, id3, id4]
    positions = ids |> Enum.map(fn(id) -> Otis.State.Source.find(id) end) |> Enum.map(fn(rec) -> rec.position end)
    assert [0, 1, 2] == positions
  end

  test "a skip deletes every unplayed source from the db", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    Otis.SourceList.append(context.source_list, sources)
    assert_receive {:new_source_created, _}, 200
    {:ok, entries} = Otis.SourceList.list(context.source_list)
    ids = Enum.map(entries, fn({id, _, _}) -> id end)
    skip_to = Enum.at(ids, -2)
    skipped_ids = Enum.take_while(ids, fn(id) -> id != skip_to end)
    kept_ids = Enum.drop_while(ids, fn(id) -> id != skip_to end)
    {:ok, 2} = Otis.SourceList.skip(context.source_list, skip_to)
    channel_id = context.channel.id
    assert_receive {:sources_skipped, ^channel_id, ^skipped_ids}
    assert [nil, nil, nil] = skipped_ids |> Enum.map(&Otis.State.Source.find/1)
    positions = kept_ids |> Enum.map(fn(id) -> Otis.State.Source.find(id) end) |> Enum.map(fn(rec) -> rec.position end)
    assert [0, 1] == positions
  end

  test "a skip deletes the currently playing source from the db", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    Otis.SourceList.append(context.source_list, sources)
    assert_receive {:new_source_created, _}, 200
    {:ok, entries} = Otis.SourceList.list(context.source_list)
    {:ok, _id, 0, _source} = Otis.SourceList.next(context.source_list)
    ids = Enum.map(entries, fn({id, _, _}) -> id end)
    skip_to = Enum.at(ids, -2)
    skipped_ids = Enum.take_while(ids, fn(id) -> id != skip_to end)
    {:ok, 2} = Otis.SourceList.skip(context.source_list, skip_to)
    channel_id = context.channel.id
    assert_receive {:sources_skipped, ^channel_id, ^skipped_ids}
  end

  test "restores source lists from db", context do
    sources = Enum.map [TestSource.new, TestSource.new], &Otis.SourceList.source_with_id/1
    sources |> Enum.with_index |> Enum.each(fn({source, position}) ->
      Otis.State.Events.notify {:new_source, context.channel.id, position, source}
    end)
    assert_receive {:new_source_created, _}
    assert_receive {:new_source_created, _}
    {:ok, []} = Otis.SourceList.list(context.source_list)
    Otis.Startup.restore_source_lists(Otis.State, Otis.Channels)
    # Otis.SourceList.append(context.source_list, [TestSource.new, TestSource.new])
    [{id1, 0, source1}, {id2, 0, source2}] = sources
    {:ok, [{ed1, 0, entry1}, {ed2, 0, entry2}]} = Otis.SourceList.list(context.source_list)
    assert id1 == ed1
    assert id2 == ed2
    assert %TestSource{source1 | loaded: true} == entry1
    assert %TestSource{source2 | loaded: true} == entry2
  end

  test "source progress events update the matching db record", context do
    sources = [TestSource.new, TestSource.new]
    Otis.SourceList.append(context.source_list, sources)
    assert_receive {:new_source_created, _}, 200
    {:ok, entries} = Otis.SourceList.list(context.source_list)
    assert [0, 0] == Enum.map entries, fn({_id, position, _source}) -> position end
    [{id1, _, _}, _] = entries
    Otis.State.Events.sync_notify({:source_progress, context.channel.id, id1, 1000, 2000})
    source = Otis.State.Source.find(id1)
    assert source.playback_position == 1000
  end
end
