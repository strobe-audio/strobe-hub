defmodule Otis.Persistence.RenditionTest do
  use   ExUnit.Case

  alias Otis.Test.TestSource
  alias Otis.Pipeline.Playlist
  alias Otis.Channel

  setup_all do
    on_exit fn ->
      Otis.State.Rendition.delete_all
      Otis.State.Channel.delete_all
    end
    {:ok, channel_id: Otis.uuid }
  end

  setup context do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach

    channel_record = Otis.State.Channel.create!(context.channel_id, "Test Channel")
    {:ok, channel} = Otis.Channels.start(channel_record)
    {:ok, playlist} = Channel.playlist(channel)

    on_exit fn ->
      Otis.Channels.destroy!(context.channel_id)
    end

    {:ok,
      channel: %Otis.Channel{pid: channel, id: channel_record.id},
      playlist: playlist,
      channel_record: channel_record,
    }
  end

  test "adding a source to a list persists to the db", context do
    Playlist.append(context.playlist, TestSource.new)
    {:ok, [rendition]} = Playlist.list(context.playlist)
    assert_receive {:new_rendition_created, _}
    [record] = Otis.State.Rendition.all
    assert record.id == rendition.id
    assert record.channel_id == context.channel.id
    assert record.source_type == to_string(TestSource)
    assert record.source_id == rendition.source_id
  end

  test "adding multiple sources persists to the db", context do
    Playlist.append(context.playlist, [TestSource.new, TestSource.new])
    {:ok, [rendition1, rendition2]} = Playlist.list(context.playlist)
    assert_receive {:new_rendition_created, _}
    assert_receive {:new_rendition_created, _}
    [record1, record2] = Otis.State.Rendition.all
    assert record1.id == rendition1.id
    assert record1.source_id == rendition1.source_id
    assert record1.channel_id == context.channel.id
    assert record1.source_type == to_string(TestSource)
    assert record1.position == 0

    assert record2.id == rendition2.id
    assert record2.source_id == rendition2.source_id
    assert record2.channel_id == context.channel.id
    assert record2.source_type == to_string(TestSource)
    assert record2.position == 1
  end

  test "you can lookup sources for a channel", context do
    Playlist.append(context.playlist, [TestSource.new, TestSource.new])
    assert_receive {:new_rendition_created, _}
    assert_receive {:new_rendition_created, _}
    {:ok, [rendition1, rendition2]} = Playlist.list(context.playlist)
    [record1, record2] = Otis.State.Rendition.for_channel(context.channel)

    assert record1.id == rendition1.id
    assert record1.source_id == rendition1.source_id
    assert record1.channel_id == context.channel.id
    assert record1.source_type == to_string(TestSource)
    assert record1.position == 0

    assert record2.id == rendition2.id
    assert record2.source_id == rendition2.source_id
    assert record2.channel_id == context.channel.id
    assert record2.source_type == to_string(TestSource)
    assert record2.position == 1
  end

  test "a source played event deletes the corresponding db record", context do
    Playlist.append(context.playlist, [TestSource.new, TestSource.new])
    {:ok, [rendition1, rendition2]} = Playlist.list(context.playlist)
    Otis.State.Events.notify({:rendition_changed, [context.channel.id, rendition1.id, rendition2.id]})
    rendition1_id = rendition1.id
    assert_receive {:old_rendition_removed, [^rendition1_id]}
    [record2] = Otis.State.Rendition.all
    assert record2.id == rendition2.id
    assert record2.source_id == rendition2.source_id
    assert record2.channel_id == context.channel.id
    assert record2.source_type == to_string(TestSource)
  end

  test "a final source played event leaves the source list empty", context do
    Playlist.append(context.playlist, [TestSource.new, TestSource.new])
    {:ok, [rendition1, rendition2]} = Playlist.list(context.playlist)
    Otis.State.Events.notify({:rendition_changed, [context.channel.id, rendition1.id, rendition2.id]})
    [rendition1_id, rendition2_id] = [rendition1.id, rendition2.id]
    assert_receive {:old_rendition_removed, [^rendition1_id]}
    Otis.State.Events.notify({:rendition_changed, [context.channel.id, rendition2_id, nil]})
    assert_receive {:old_rendition_removed, [^rendition2_id]}
    [] = Otis.State.Rendition.all
  end

  test "a source played event updates the db positions", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    Playlist.append(context.playlist, sources)
    assert_receive {:new_rendition_created, _}
    {:ok, [rendition1, rendition2, rendition3, rendition4]} = Playlist.list(context.playlist)
    ids = [id1, id2, id3, id4] = [rendition1.id, rendition2.id, rendition3.id, rendition4.id]
    positions = ids |> Enum.map(fn(id) -> Otis.State.Rendition.find(id) end) |> Enum.map(fn(rec) -> rec.position end)
    assert [0, 1, 2, 3] == positions
    Otis.State.Events.notify({:rendition_changed, [context.channel.id, id1, id2]})
    assert_receive {:old_rendition_removed, [^id1]}
    ids = [id2, id3, id4]
    positions = ids |> Enum.map(fn(id) -> Otis.State.Rendition.find(id) end) |> Enum.map(fn(rec) -> rec.position end)
    assert [0, 1, 2] == positions
  end

  test "a skip deletes every unplayed source from the db", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    Playlist.append(context.playlist, sources)
    assert_receive {:new_rendition_created, _}, 200
    {:ok, renditions} = Playlist.list(context.playlist)
    ids = Enum.map(renditions, fn(r) -> r.id end)
    skip_to = Enum.at(ids, -2)
    skipped_ids = Enum.take_while(ids, fn(id) -> id != skip_to end)
    kept_ids = Enum.drop_while(ids, fn(id) -> id != skip_to end)
    :ok = Playlist.skip(context.playlist, skip_to)
    channel_id = context.channel.id
    assert_receive {:renditions_skipped, [^channel_id, ^skipped_ids]}
    assert [nil, nil, nil] = skipped_ids |> Enum.map(&Otis.State.Rendition.find/1)
    positions = kept_ids |> Enum.map(fn(id) -> Otis.State.Rendition.find(id) end) |> Enum.map(fn(rec) -> rec.position end)
    assert [0, 1] == positions
  end

  test "a skip deletes the currently playing source from the db", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    Playlist.append(context.playlist, sources)
    assert_receive {:new_rendition_created, _}, 200
    {:ok, renditions} = Playlist.list(context.playlist)
    {:ok, _rendition} = Playlist.next(context.playlist)
    ids = Enum.map(renditions, fn(r) -> r.id end)
    skip_to = Enum.at(ids, -2)
    skipped_ids = Enum.take_while(ids, fn(id) -> id != skip_to end)
    :ok = Playlist.skip(context.playlist, skip_to)
    channel_id = context.channel.id
    assert_receive {:renditions_skipped, [^channel_id, ^skipped_ids]}
  end

  test "restores source lists from db", context do
    sources = [TestSource.new, TestSource.new]
    renditions = sources |> Enum.with_index |> Enum.map(fn({source, position}) ->
      Playlist.make_rendition(source, position, context.channel.id)
    end)
    Otis.State.Events.notify {:new_renditions, [context.channel.id, renditions]}
    assert_receive {:new_rendition_created, _}
    assert_receive {:new_rendition_created, _}
    {:ok, []} = Playlist.list(context.playlist)
    Otis.Startup.restore_source_lists(Otis.State, Otis.Channels)
    [id1, id2] = Enum.map(renditions, fn(r) -> r.id end)
    {:ok, [r1, r2]} = Playlist.list(context.playlist)
    assert r1.id == id1
    assert r2.id == id2
  end

  test "source progress events update the matching db record", context do
    sources = [TestSource.new, TestSource.new]
    Playlist.append(context.playlist, sources)
    assert_receive {:new_rendition_created, _}, 200
    {:ok, renditions} = Playlist.list(context.playlist)
    assert [0, 0] == Enum.map renditions, fn(r) -> r.playback_position end
    [r1, _] = renditions
    Otis.State.Events.sync_notify({:rendition_progress, [context.channel.id, r1.id, 1000, 2000]})
    rendition = Otis.State.Rendition.find(r1.id)
    assert rendition.playback_position == 1000
  end

  test "insertion of a live source with infinte duration", context do
    sources = [TestSource.new(:infinity)]
    Playlist.append(context.playlist, sources)
    assert_receive {:new_rendition_created, _}, 200
    {:ok, [rendition]} = Playlist.list(context.playlist)
    assert rendition.playback_duration == nil
  end
end
