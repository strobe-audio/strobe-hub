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
    MessagingHandler.attach
    sources = [
      TS.new("a"),
      TS.new("b"),
      TS.new("c"),
      TS.new("d"),
    ]
    id = Otis.uuid
    {:ok, sources: sources, id: id}
  end

  test "it creates renditions from sources", context do
    channel_id = context.id
    {:ok, pl} = Playlist.start_link(channel_id)
    Playlist.append(pl, context.sources)
    {:ok, renditions} = Playlist.list(pl)
    assert length(renditions) == length(context.sources)
    [r0, r1, r2, r3] = renditions
    %Rendition{position: 0, source_id: "a", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: ^channel_id, playback_duration: 1000} = r0
    %Rendition{position: 1, source_id: "b", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: ^channel_id, playback_duration: 1000} = r1
    %Rendition{position: 2, source_id: "c", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: ^channel_id, playback_duration: 1000} = r2
    %Rendition{position: 3, source_id: "d", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: ^channel_id, playback_duration: 1000} = r3
    ids = Enum.map(renditions, fn(%{id: id}) -> id end)
    assert 4 == length(Enum.uniq(ids))
  end

  test "it emits an event listing the new renditions", context do
    channel_id = context.id
    {:ok, pl} = Playlist.start_link(channel_id)
    Playlist.append(pl, context.sources)
    {:ok, renditions} = Playlist.list(pl)
    assert_receive {:new_renditions, [^channel_id, ^renditions]}, 200
  end

  test "it returns the next rendition", context do
    channel_id = context.id
    {:ok, pl} = Playlist.start_link(channel_id)
    Playlist.append(pl, context.sources)
    {:ok, renditions} = Playlist.list(pl)
    [r0, r1, r2, r3] = renditions

    {:ok, r} = Playlist.next(pl)
    assert r == r0
    {:ok, r} = Playlist.next(pl)
    assert r == r1
    {:ok, r} = Playlist.next(pl)
    assert r == r2
    {:ok, r} = Playlist.next(pl)
    assert r == r3
    :done = Playlist.next(pl)
  end

  test "it can replace its contents", context do
    channel_id = context.id
    {:ok, pl} = Playlist.start_link(channel_id)
    Playlist.append(pl, context.sources)
    renditions = [a, b] = [
      %Rendition{id: "e", position: 0, source_id: "e", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: channel_id},
      %Rendition{id: "f", position: 0, source_id: "f", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: channel_id},
    ]
    Playlist.replace(pl, renditions)
    {:ok, [r0, r1]} = Playlist.list(pl)
    assert r0 == a
    assert r1 == b
    {:ok, r} = Playlist.next(pl)
    assert r == a
  end

  test "it gives a correct value for the playlist duration", context do
    channel_id = context.id
    {:ok, pl} = Playlist.start_link(channel_id)
    renditions = [
      %Rendition{id: "e", position: 0, source_id: "e", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: channel_id, playback_position: 100, playback_duration: 10_000},
      %Rendition{id: "f", position: 0, source_id: "f", source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: channel_id, playback_position: 0, playback_duration: 10_000},
    ]
    Playlist.replace(pl, renditions)
    {:ok, d} = Playlist.duration(pl)
    assert d == 19_900
  end

  test "clear playlist", context do
    channel_id = context.id
    {:ok, pl} = Playlist.start_link(channel_id)
    Playlist.append(pl, context.sources)
    {:ok, renditions} = Playlist.list(pl)
    Playlist.clear(pl)
    {:ok, r} = Playlist.list(pl)
    assert r == []
    Enum.each renditions, fn(%Rendition{id: rendition_id}) ->
      assert_receive {:rendition_deleted, [^rendition_id, ^channel_id]}
    end

    assert_receive {:playlist_cleared, [^channel_id]}
  end

  test "clear playlist with active rendition", context do
    channel_id = context.id
    {:ok, pl} = Playlist.start_link(channel_id)
    Playlist.append(pl, context.sources)
    {:ok, r} = Playlist.next(pl)
    Playlist.clear(pl)
    {:ok, renditions} = Playlist.list(pl)
    assert renditions == [r]
  end

  test "skip to rendition", context do
    channel_id = context.id
    {:ok, pl} = Playlist.start_link(channel_id)
    ids = Enum.map(0..5, fn(_) -> Otis.uuid() end)
    renditions = [a, _b, _c, _d, e, f] = Enum.map(ids, fn(id) ->
      %Rendition{id: id, position: 0, source_id: id, source_type: "Elixir.Test.Otis.Pipeline.Source", channel_id: channel_id}
    end)
    [aid, bid, cid, did, eid, _fid] = ids

    Playlist.replace(pl, renditions)
    {:ok, r} = Playlist.next(pl)
    assert r == a
    Playlist.skip(pl, eid)
    {:ok, renditions} = Playlist.list(pl)
    assert renditions == [e, f]
    assert_receive {:rendition_deleted, [^aid, ^channel_id]}
    assert_receive {:rendition_deleted, [^bid, ^channel_id]}
    assert_receive {:rendition_deleted, [^cid, ^channel_id]}
    assert_receive {:rendition_deleted, [^did, ^channel_id]}
  end


  test "it appends sources in the right position", context do
    channel_id = context.id
    {:ok, pl} = Playlist.start_link(channel_id)
    Playlist.append(pl, context.sources)
    {:ok, r} = Playlist.next(pl)
    assert r.position == 0
    Playlist.append(pl, context.sources)
    {:ok, renditions} = Playlist.list(pl)
    assert Enum.map(renditions, fn(r) -> r.position end) == [0, 1, 2, 3, 4, 5, 6, 7]
  end

  test "clears the active rendition when empty", context do
    channel_id = context.id
    [s1, _, _, _] = context.sources
    {:ok, pl} = Playlist.start_link(channel_id)
    :ok = Playlist.append(pl, s1)
    assert_receive {:new_rendition_created, _}, 500
    {:ok, _} = Playlist.next(pl)
    :done = Playlist.next(pl)
    assert {:ok, []} == Playlist.list(pl)
  end
end
