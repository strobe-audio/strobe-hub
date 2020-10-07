defmodule Test.Otis.Pipeline.Source do
  defstruct [:id]

  def new(id) do
    %__MODULE__{id: id}
  end
end

defimpl Otis.Library.Source, for: Test.Otis.Pipeline.Source do
  def id(%{id: id}), do: id
  def type(_), do: Test.Otis.Pipeline.Source
  def open!(_source, _id, _packet_size_bytes), do: []
  def close(_source, _id, _stream), do: nil
  def pause(_source, _id, _stream), do: nil
  def transcoder_args(_source), do: ["-f", "mp3"]
  def metadata(_source), do: %Otis.Source.Metadata{}

  def duration(_source) do
    {:ok, 1000}
  end
end

defimpl Otis.Library.Source.Origin, for: Test.Otis.Pipeline.Source do
  def load!(source) do
    source
  end
end

defmodule Test.Otis.Pipeline.Playlist do
  use ExUnit.Case

  alias Test.Otis.Pipeline.Source, as: TS
  alias Otis.Pipeline.Playlist
  alias Otis.State.Rendition

  def build_playlist(context) do
    build_playlist(context, context.sources)
  end

  def build_playlist(%{id: channel_id} = context, sources) do
    Playlist.append(context.pl, sources)
    assert_receive {:playlist, :append, [^channel_id, _]}

    assert_receive {:__complete__, {:playlist, :append, [^channel_id, _]},
                    Otis.State.Persistence.Playlist}

    Playlist.list(context.pl)
  end

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach()

    sources = [
      TS.new("a"),
      TS.new("b"),
      TS.new("c"),
      TS.new("d")
    ]

    id = Otis.uuid()

    {:ok, pl} = Playlist.start_link(id)

    on_exit(fn ->
      if Process.alive?(pl) do
        GenServer.stop(pl)
      end
    end)

    channel =
      id
      |> Otis.State.Channel.create!("Test Channel")

    {:ok, pl: pl, sources: sources, id: id, channel: channel}
  end

  test "it emits an event listing the new renditions", context do
    channel_id = context.id
    {:ok, rendition_ids} = build_playlist(context)
    renditions = Enum.map(rendition_ids, &Rendition.find/1)
    [r0, r1, r2, r3] = renditions

    %Rendition{
      source_id: "a",
      source_type: "Elixir.Test.Otis.Pipeline.Source",
      channel_id: ^channel_id,
      playback_duration: 1000
    } = r0

    %Rendition{
      source_id: "b",
      source_type: "Elixir.Test.Otis.Pipeline.Source",
      channel_id: ^channel_id,
      playback_duration: 1000
    } = r1

    %Rendition{
      source_id: "c",
      source_type: "Elixir.Test.Otis.Pipeline.Source",
      channel_id: ^channel_id,
      playback_duration: 1000
    } = r2

    %Rendition{
      source_id: "d",
      source_type: "Elixir.Test.Otis.Pipeline.Source",
      channel_id: ^channel_id,
      playback_duration: 1000
    } = r3
  end

  test "it returns the next rendition", context do
    {:ok, rendition_ids} = build_playlist(context)
    [r0, r1, r2, r3] = rendition_ids

    Enum.each(rendition_ids, fn r ->
      assert is_binary(r)
    end)

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
    {:ok, _rendition_ids} = build_playlist(context)

    renditions = [
      %Rendition{
        id: "e",
        position: 0,
        source_id: "e",
        source_type: "Elixir.Test.Otis.Pipeline.Source",
        channel_id: channel_id
      },
      %Rendition{
        id: "f",
        position: 0,
        source_id: "f",
        source_type: "Elixir.Test.Otis.Pipeline.Source",
        channel_id: channel_id
      }
    ]

    Playlist.replace(context.pl, renditions)
    {:ok, [r0, r1]} = Playlist.list(context.pl)
    assert r0 == "e"
    assert r1 == "f"
    {:ok, r} = Playlist.next(context.pl)
    assert r == "e"
  end

  test "clear playlist without active rendition", context do
    channel_id = context.id
    {:ok, renditions} = build_playlist(context)
    assert {:ok, nil} == Playlist.active_rendition(context.pl)
    Playlist.clear(context.pl)
    {:ok, r} = Playlist.list(context.pl)
    assert r == []

    Enum.each(renditions, fn rendition_id ->
      assert_receive {:rendition, :delete, [^rendition_id, ^channel_id]}
    end)

    assert_receive {:playlist, :clear, [^channel_id, nil]}
  end

  test "skip to rendition", context do
    channel_id = context.id

    sources = [
      TS.new("a"),
      TS.new("b"),
      TS.new("c"),
      TS.new("d"),
      TS.new("e"),
      TS.new("f")
    ]

    {:ok, renditions} = build_playlist(context, sources)
    [aid, bid, cid, did, eid, fid] = renditions

    {:ok, r} = Playlist.next(context.pl)
    assert r == aid
    Playlist.skip(context.pl, eid)
    assert_receive {:playlist, :skip, [^channel_id, ^eid, _]}

    assert_receive {:__complete__, {:playlist, :skip, [^channel_id, ^eid, _]},
                    Otis.State.Persistence.Playlist}

    {:ok, renditions} = Playlist.list(context.pl)
    assert renditions == [eid, fid]
    assert_receive {:rendition, :skip, [^channel_id, ^aid]}
    assert_receive {:rendition, :skip, [^channel_id, ^bid]}
    assert_receive {:rendition, :skip, [^channel_id, ^cid]}
    assert_receive {:rendition, :skip, [^channel_id, ^did]}
  end

  test "skip to next", context do
    channel_id = context.id

    sources = [
      TS.new("a"),
      TS.new("b"),
      TS.new("c")
    ]

    {:ok, renditions} = build_playlist(context, sources)
    [aid, bid, cid] = renditions

    Playlist.skip(context.pl, :next)
    assert_receive {:playlist, :skip, [^channel_id, ^bid, _]}

    assert_receive {:__complete__, {:playlist, :skip, [^channel_id, ^bid, _]},
                    Otis.State.Persistence.Playlist}

    {:ok, renditions} = Playlist.list(context.pl)
    assert renditions == [bid, cid]
    assert_receive {:rendition, :skip, [^channel_id, ^aid]}
  end

  test "skip to next with active rendition", context do
    channel_id = context.id

    sources = [
      TS.new("a"),
      TS.new("b"),
      TS.new("c")
    ]

    {:ok, renditions} = build_playlist(context, sources)
    [aid, bid, cid] = renditions

    {:ok, r} = Playlist.next(context.pl)
    assert r == aid
    Playlist.skip(context.pl, :next)
    assert_receive {:playlist, :skip, [^channel_id, ^bid, _]}

    assert_receive {:__complete__, {:playlist, :skip, [^channel_id, ^bid, _]},
                    Otis.State.Persistence.Playlist}

    {:ok, renditions} = Playlist.list(context.pl)
    assert renditions == [bid, cid]
    assert_receive {:rendition, :skip, [^channel_id, ^aid]}
  end

  test "it appends sources in the right position", context do
    channel_id = context.id
    {:ok, _renditions} = build_playlist(context)
    {:ok, _r} = Playlist.next(context.pl)
    Playlist.append(context.pl, context.sources)

    assert_receive {:__complete__, {:playlist, :append, [^channel_id, _]},
                    Otis.State.Persistence.Playlist}

    {:ok, [first | _] = rendition_ids} = Playlist.list(context.pl)
    channel = Otis.State.Channel.find(channel_id)
    assert channel.current_rendition_id == first
    renditions = Otis.State.Playlist.list(channel)
    assert rendition_ids == Enum.map(renditions, & &1.id)
  end

  test "retreiving the active rendition", context do
    assert {:ok, nil} == Playlist.active_rendition(context.pl)
    {:ok, _renditions} = build_playlist(context)
    assert {:ok, nil} == Playlist.active_rendition(context.pl)
    {:ok, r} = Playlist.next(context.pl)
    assert {:ok, r} == Playlist.active_rendition(context.pl)
  end

  test "clear playlist with active rendition", context do
    channel_id = context.id
    {:ok, _renditions} = build_playlist(context)
    {:ok, r1} = Playlist.next(context.pl)
    assert {:ok, r1} == Playlist.active_rendition(context.pl)
    {:ok, [^r1, _r2, _r3, _r4] = [_ | renditions]} = Playlist.list(context.pl)
    Playlist.clear(context.pl)
    assert_receive {:playlist, :clear, [^channel_id, ^r1]}
    assert {:ok, r1} == Playlist.active_rendition(context.pl)
    {:ok, l} = Playlist.list(context.pl)
    assert l == [r1]

    Enum.each(renditions, fn rendition_id ->
      assert_receive {:rendition, :delete, [^rendition_id, ^channel_id]}
    end)

    refute_receive {:rendition, :delete, [^r1, ^channel_id]}
  end

  test "clears the active rendition when empty", context do
    [s1, _, _, _] = context.sources
    {:ok, _renditions} = build_playlist(context, s1)
    {:ok, _} = Playlist.next(context.pl)
    :done = Playlist.next(context.pl)
    assert {:ok, []} == Playlist.list(context.pl)
  end

  test "event when rendition becomes active", context do
    channel_id = context.id
    {:ok, _renditions} = build_playlist(context)
    {:ok, rendition_id} = Playlist.next(context.pl)
    assert_receive {:rendition, :active, [^channel_id, ^rendition_id]}
    {:ok, rendition_id} = Playlist.next(context.pl)
    assert_receive {:rendition, :active, [^channel_id, ^rendition_id]}
  end

  test "removal of single rendition", context do
    channel_id = context.id
    {:ok, [a, b, _c, d] = ids} = build_playlist(context)
    id = Enum.at(ids, 2)
    Playlist.remove(context.pl, id)
    {:ok, [^a, ^b, ^d]} = Playlist.list(context.pl)
    assert_receive {:playlist, :remove, [^id, ^channel_id]}
    assert_receive {:__complete__, {:rendition, :delete, [^id, ^channel_id]}, _}
    assert nil == Rendition.find(id)
  end
end
