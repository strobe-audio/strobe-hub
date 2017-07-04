defmodule Test.Otis.Pipeline.Source do
  defstruct [:id]
  def new(id) do
    %__MODULE__{ id: id }
  end
end

defimpl Otis.Library.Source, for: Test.Otis.Pipeline.Source do
  def id(%{id: id}), do: id
  def type(_), do: Test.Otis.Pipeline.Source
  def open!(_source, _id, _packet_size_bytes), do: []
  def close(_file, _id, _source), do: nil
  def pause(_file, _id, _source), do: nil
  def transcoder_args(_source), do: ["-f", "mp3"]
  def metadata(_source), do: %Otis.Source.Metadata{}
  def duration(_source) do
    {:ok, 1000}
  end
end

defmodule Test.Otis.Pipeline.Playlist do
  use ExUnit.Case

  alias Test.Otis.Pipeline.Source, as: TS
  alias Otis.Pipeline.Playlist
  alias Otis.State.Rendition

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach
    sources = [
      TS.new("a"),
      TS.new("b"),
      TS.new("c"),
      TS.new("d"),
    ]
    id = Otis.uuid

    {:ok, pl} = Playlist.start_link(id)

    on_exit fn ->
      if Process.alive?(pl) do
        GenServer.stop(pl)
      end
    end

    channel =
      id
      |> Otis.State.Channel.create!("Test Channel")

    {:ok, pl: pl, sources: sources, id: id, channel: channel}
  end

  test "it emits an event listing the new renditions", context do
    channel_id = context.id
    Playlist.append(context.pl, context.sources)
    {:ok, _rendition_ids} = Playlist.list(context.pl)
    assert_receive {:append_renditions, [^channel_id, renditions]}, 200
    assert_receive {:"$__append_renditions", [^channel_id]}
    renditions = Enum.map(renditions, &Rendition.find(&1.id))
    [r0, r1, r2, r3] = renditions
    %Rendition{source_id: "a", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: ^channel_id, playback_duration: 1000} = r0
    %Rendition{source_id: "b", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: ^channel_id, playback_duration: 1000} = r1
    %Rendition{source_id: "c", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: ^channel_id, playback_duration: 1000} = r2
    %Rendition{source_id: "d", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: ^channel_id, playback_duration: 1000} = r3
  end

  test "it returns the next rendition", context do
    channel_id = context.id
    Playlist.append(context.pl, context.sources)
    assert_receive {:"$__append_renditions", [^channel_id]}
    {:ok, rendition_ids} = Playlist.list(context.pl)
    [r0, r1, r2, r3] = rendition_ids
    Enum.each rendition_ids, fn r ->
      assert is_binary(r)
    end

    {:ok, r} = Playlist.next(context.pl)
    assert r == r0
    {:ok, r} = Playlist.next(context.pl)
    assert r == r1
    {:ok, r} = Playlist.next(context.pl)
    assert r == r2
    {:ok, r} = Playlist.next(context.pl)
    assert r == r3
    :done = Playlist.next(context.pl)
  end

  test "it can replace its contents", context do
    channel_id = context.id
    Playlist.append(context.pl, context.sources)
    assert_receive {:"$__append_renditions", [^channel_id]}
    renditions = [
      %Rendition{id: "e", position: 0, source_id: "e", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: channel_id},
      %Rendition{id: "f", position: 0, source_id: "f", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: channel_id},
    ]
    Playlist.replace(context.pl, renditions)
    {:ok, [r0, r1]} = Playlist.list(context.pl)
    assert r0 == "e"
    assert r1 == "f"
    {:ok, r} = Playlist.next(context.pl)
    assert r == "e"
  end

  test "clear playlist", context do
    channel_id = context.id
    Playlist.append(context.pl, context.sources)
    assert_receive {:"$__append_renditions", [^channel_id]}
    {:ok, [_r1, _r2, _r3, _r4] = renditions} = Playlist.list(context.pl)
    Playlist.clear(context.pl)
    {:ok, r} = Playlist.list(context.pl)
    assert r == []
    Enum.each renditions, fn(rendition_id) ->
      assert_receive {:rendition_deleted, [^rendition_id, ^channel_id]}
    end

    assert_receive {:playlist_cleared, [^channel_id]}
  end

  test "clear playlist with active rendition", context do
    channel_id = context.id
    Playlist.append(context.pl, context.sources)
    assert_receive {:"$__append_renditions", [^channel_id]}
    {:ok, _r} = Playlist.next(context.pl)
    {:ok, [_r1, _r2, _r3, _r4] = renditions} = Playlist.list(context.pl)
    Playlist.clear(context.pl)
    {:ok, r} = Playlist.list(context.pl)
    assert r == []
    Enum.each renditions, fn(rendition_id) ->
      assert_receive {:rendition_deleted, [^rendition_id, ^channel_id]}
    end

    assert_receive {:playlist_cleared, [^channel_id]}
  end

  test "skip to rendition", context do
    channel_id = context.id
    sources = [
      TS.new("a"), TS.new("b"), TS.new("c"),
      TS.new("d"), TS.new("e"), TS.new("f"),
    ]
    Playlist.append(context.pl, sources)
    assert_receive {:"$__append_renditions", [^channel_id]}
    assert_receive {:append_renditions, [^channel_id, renditions]}
    [aid, bid, cid, did, eid, fid] = Enum.map(renditions, & &1.id)

    {:ok, r} = Playlist.next(context.pl)
    assert r == aid
    Playlist.skip(context.pl, eid)
    assert_receive {:renditions_skipped, [^channel_id, ^eid, _]}
    assert_receive {:"$__rendition_skip", [^channel_id]}
    {:ok, renditions} = Playlist.list(context.pl)
    assert renditions == [eid, fid]
    assert_receive {:rendition_deleted, [^aid, ^channel_id]}
    assert_receive {:rendition_deleted, [^bid, ^channel_id]}
    assert_receive {:rendition_deleted, [^cid, ^channel_id]}
    assert_receive {:rendition_deleted, [^did, ^channel_id]}
  end


  test "it appends sources in the right position", context do
    channel_id = context.id
    Playlist.append(context.pl, context.sources)
    assert_receive {:"$__append_renditions", [^channel_id]}
    {:ok, _r} = Playlist.next(context.pl)
    Playlist.append(context.pl, context.sources)
    assert_receive {:"$__append_renditions", [^channel_id]}
    {:ok, [first | _] = rendition_ids} = Playlist.list(context.pl)
    channel = Otis.State.Channel.find(channel_id)
    assert channel.current_rendition_id == first
    renditions = Otis.State.Playlist.list(channel)
    assert rendition_ids == Enum.map(renditions, & &1.id)
  end

  test "clears the active rendition when empty", context do
    channel_id = context.id
    [s1, _, _, _] = context.sources
    :ok = Playlist.append(context.pl, s1)
    assert_receive {:"$__append_renditions", [^channel_id]}
    assert_receive {:new_rendition_created, _}, 500
    {:ok, _} = Playlist.next(context.pl)
    :done = Playlist.next(context.pl)
    assert {:ok, []} == Playlist.list(context.pl)
  end

  test "removal of single rendition", context do
    channel_id = context.id
    Playlist.append(context.pl, context.sources)
    assert_receive {:"$__append_renditions", [^channel_id]}
    {:ok, [a, b, _c, d] = ids} = Playlist.list(context.pl)
    id = Enum.at(ids, 2)
    Playlist.remove(context.pl, id)
    {:ok, [^a, ^b, ^d]} = Playlist.list(context.pl)
    assert_receive {:rendition_remove, [^id, ^channel_id]}
    assert_receive {:"$__rendition_remove", [^channel_id]}
    assert nil == Rendition.find(id)
  end
end
