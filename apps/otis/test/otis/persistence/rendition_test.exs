defmodule Otis.Persistence.RenditionTest do
  use   ExUnit.Case

  alias Otis.Test.TestSource
  alias Otis.State
  alias State.Rendition
  alias State.Persistence
  alias Otis.Pipeline.Playlist
  alias Otis.Channel

  setup_all do
    {:ok, channel_id: Otis.uuid, profile_id: Otis.uuid}
  end

  setup context do
    Ecto.Adapters.SQL.restart_test_transaction(State.Repo)
    MessagingHandler.attach

    channel_record =
      context.channel_id
      |> State.Channel.create!("Test Channel")
      |> State.Channel.update(profile_id: context.profile_id)

    {:ok, channel} = Otis.Channels.start(channel_record)
    {:ok, playlist} = Channel.playlist(channel)

    on_exit fn ->
      # delay exit as otherwise events still in pipeline will find themselves
      # working against a suddenly empty db and will raise errors from missing
      # renditions
      Process.sleep(10)
      Otis.Channels.destroy!(context.channel_id)
    end

    {:ok,
      channel: %Otis.Channel{pid: channel, id: channel_record.id},
      playlist: playlist,
      channel_record: channel_record,
      state: %{
        channel: channel_record,
      }
    }
  end

  def channel(%{channel_id: id}), do: State.Channel.find(id)

  def build_playlist(%{channel: %{id: channel_id}} = context, sources) do
    Playlist.append(context.playlist, sources)
    assert_receive {:__complete__, {:playlist, :append, [^channel_id, _]}, Persistence.Playlist}
    sources |> List.wrap |> Enum.each(fn(_) ->
      assert_receive {:rendition, :create, [%Rendition{}]}
    end)
    Playlist.list(context.playlist)
  end

  test "adding a source to a list persists to the db", context do
    {:ok, [id1]} = build_playlist(context, TestSource.new)
    [rendition] = [id1] |> Enum.map(&Rendition.find/1)
    [record] = State.Playlist.list(channel(context))
    assert record.id == rendition.id
    assert record.channel_id == context.channel.id
    assert record.source_type == to_string(TestSource)
    assert record.source_id == rendition.source_id
  end

  test "adding multiple sources persists to the db", context do
    {:ok, [id1, id2]} = build_playlist(context, [TestSource.new, TestSource.new])
    [rendition1, rendition2] = [id1, id2] |> Enum.map(&Rendition.find/1)
    [record1, record2] = State.Playlist.list(channel(context))
    assert record1.id == rendition1.id
    assert record1.source_id == rendition1.source_id
    assert record1.channel_id == context.channel.id
    assert record1.source_type == to_string(TestSource)

    assert record2.id == rendition2.id
    assert record2.source_id == rendition2.source_id
    assert record2.channel_id == context.channel.id
    assert record2.source_type == to_string(TestSource)
  end

  test "a source played event progresses the channel playlist", context do
    {:ok, [id1, id2]} = build_playlist(context, [TestSource.new, TestSource.new])
    [rendition1, rendition2] = [id1, id2] |> Enum.map(&Rendition.find/1)
    Strobe.Events.notify(:playlist, :advance, [context.channel.id, rendition1.id, rendition2.id])
    rendition1_id = rendition1.id
    evt = {:playlist, :advance, [context.channel.id, rendition1.id, rendition2.id]}
    assert_receive {:__complete__, ^evt, Persistence.Playlist}
    assert_receive {:rendition, :played, [^rendition1_id]}
    [record2] = State.Playlist.list(channel(context))
    assert record2.id == rendition2.id
    assert record2.source_id == rendition2.source_id
    assert record2.channel_id == context.channel.id
    assert record2.source_type == to_string(TestSource)

    rendition = Rendition.find(rendition1.id)
    refute rendition == nil
  end

  test "a final source played event leaves the source list empty", context do
    {:ok, [id1, id2]} = build_playlist(context, [TestSource.new, TestSource.new])
    Strobe.Events.notify(:playlist, :advance, [context.channel.id, id1, id2])
    evt = {:playlist, :advance, [context.channel.id, id1, id2]}
    assert_receive {:__complete__, ^evt, Persistence.Playlist}
    Strobe.Events.notify(:playlist, :advance, [context.channel.id, id2, nil])
    evt = {:playlist, :advance, [context.channel.id, id2, nil]}
    assert_receive {:__complete__, ^evt, Persistence.Playlist}
    assert_receive {:rendition, :played, [^id2]}
    [] = State.Playlist.list(channel(context))
  end

  test "a skip does not delete unplayed source from the db", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    {:ok, ids} = build_playlist(context, sources)
    skip_to = Enum.at(ids, -2)
    skipped_ids = Enum.take_while(ids, fn(id) -> id != skip_to end)
    kept_ids = Enum.drop_while(ids, fn(id) -> id != skip_to end)
    :ok = Playlist.skip(context.playlist, skip_to)
    channel_id = context.channel.id
    evt = {:playlist, :skip, [channel_id, skip_to, skipped_ids]}
    assert_receive ^evt
    assert_receive {:__complete__, ^evt, Persistence.Playlist}
    assert [%State.Rendition{}, %State.Rendition{}, %State.Rendition{}] = skipped_ids |> Enum.map(&State.Rendition.find/1)
    renditions = kept_ids |> Enum.map(fn(id) -> State.Rendition.find(id) end)
    assert renditions == State.Playlist.list(channel(context))
    for id <- skipped_ids do
      refute_received {:rendition, :delete, [^channel_id, ^id]}
      assert_received {:rendition, :skip, [^channel_id, ^id]}
    end
  end

  test "a skip does not delete the currently playing source from the db", context do
    sources = [TestSource.new, TestSource.new, TestSource.new, TestSource.new, TestSource.new]
    {:ok, ids} = build_playlist(context, sources)
    {:ok, _rendition} = Playlist.next(context.playlist)
    skip_to = Enum.at(ids, -2)
    skipped_ids = Enum.take_while(ids, fn(id) -> id != skip_to end)
    :ok = Playlist.skip(context.playlist, skip_to)
    channel_id = context.channel.id
    evt = {:playlist, :skip, [channel_id, skip_to, skipped_ids]}
    assert_receive ^evt
    assert_receive {:__complete__, ^evt, Persistence.Playlist}
    assert Enum.map(skipped_ids, &Rendition.find/1) != List.duplicate(nil, length(skipped_ids))
  end

  test "restores source lists from db", context do
    sources = [TestSource.new, TestSource.new]
    renditions = sources |> Enum.map(fn(source) ->
      Rendition.from_source(source)
    end)
    Strobe.Events.notify(:playlist, :append, [context.channel.id, renditions])
    assert_receive {:rendition, :create, _}
    assert_receive {:rendition, :create, _}
    {:ok, []} = Playlist.list(context.playlist)
    Otis.Startup.restore_source_lists(State, Otis.Channels)
    [id1, id2] = Enum.map(renditions, fn(r) -> r.id end)
    {:ok, [r1, r2]} = Playlist.list(context.playlist)
    assert r1 == id1
    assert r2 == id2
  end

  test "source progress events update the matching db record", context do
    sources = [TestSource.new, TestSource.new]
    {:ok, [r1id, _]} = build_playlist(context, sources)
    Strobe.Events.notify(:rendition, :progress, [context.channel.id, r1id, 1000, 2000])
    evt = {:rendition, :progress, [context.channel.id, r1id, 1000, 2000]}
    assert_receive {:__complete__, ^evt, Persistence.Renditions}
    State.RenditionProgress.save()
    rendition = State.Rendition.find(r1id)
    assert rendition.playback_position == 1000
  end

  test "insertion of a live source with infinte duration", context do
    sources = [TestSource.new(:infinity)]
    {:ok, [id]} = build_playlist(context, sources)
    rendition = Rendition.find(id)
    assert rendition.playback_duration == nil
  end

  test "removing a rendition", context do
    {:ok, [r1id, r2id]} = build_playlist(context, [TestSource.new, TestSource.new])
    Playlist.remove(context.playlist, r2id)
    evt = {:playlist, :remove, [r2id, context.channel.id]}
    assert_receive {:__complete__, ^evt, Persistence.Playlist}
    assert nil == State.Rendition.find(r2id)
    assert [r1id] == State.Playlist.map(channel(context), fn(r) -> r.id end)
  end

  test "removing the active rendition", context do
    {:ok, [r1id, _r2id]} = build_playlist(context, [TestSource.new, TestSource.new])
    {:ok, _r} = Playlist.next(context.playlist)
    Playlist.remove(context.playlist, r1id)
    evt = {:playlist, :remove, [r1id, context.channel.id]}
    assert_receive {:__complete__, ^evt, Persistence.Playlist}
    assert nil == State.Rendition.find(r1id)
  end

  test "removing a source removes all associated renditions", context do
    source = TestSource.new
    {:ok, [id]} = build_playlist(context, source)
    Strobe.Events.notify(:rendition, :source_delete, [Otis.Library.Source.type(source), Otis.Library.Source.id(source)])
    evt = {:rendition, :delete, [id, context.channel.id]}
    assert_receive ^evt
    assert nil == Rendition.find(id)
  end

  test "emits events when cleared", context do
    {:ok, [r1id, r2id]} = build_playlist(context, [TestSource.new, TestSource.new])

    Playlist.clear(context.playlist)

    Enum.each [r1id, r2id], fn(id) ->
      evt = {:rendition, :delete, [id, context.channel.id]}
      assert_receive ^evt
    end

    evt = {:playlist, :clear, [context.channel.id, nil]}
    assert_receive ^evt
  end

  test "deletes the matching db entries when cleared", context do
    {:ok, [r1id, r2id]} = build_playlist(context, [TestSource.new, TestSource.new])
    assert Enum.map(Rendition.all, fn(s) -> s.id end) == [r1id, r2id]

    Playlist.clear(context.playlist)

    Enum.each [r1id, r2id], fn(id) ->
      evt = {:rendition, :delete, [id, context.channel.id]}
      assert_receive ^evt
    end

    evt = {:playlist, :clear, [context.channel.id, nil]}
    assert_receive ^evt
    assert_receive {:__complete__, ^evt, Persistence.Playlist}
    # assert Rendition.all == []
    assert [] == State.Playlist.list(channel(context))
  end
end
