defmodule Otis.Persistence.SourceListTest do
  use   ExUnit.Case
  alias Otis.Test.TestSource
  alias Otis.Pipeline.Playlist
  alias Otis.State.Rendition

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach()
    id = Otis.uuid()
    {:ok, playlist} = Playlist.start_link(id)

    {:ok, id: id, playlist: playlist}
  end

  test "emits events  when cleared", %{id: list_id} = context do
    :ok = Playlist.append(context.playlist, TestSource.new)
    assert_receive {:new_rendition_created, _}
    :ok = Playlist.append(context.playlist, TestSource.new)
    assert_receive {:new_rendition_created, _}
    {:ok, [rendition1, rendition2]} = Playlist.list(context.playlist)

    Playlist.clear(context.playlist)

    Enum.each [rendition1, rendition2], fn(%Rendition{id: id}) ->
      assert_receive {:rendition_deleted, [^id, ^list_id]}
    end

    assert_receive {:playlist_cleared, [^list_id]}
  end

  test "deletes the matching db entries when cleared", %{id: list_id} = context do
    :ok = Playlist.append(context.playlist, TestSource.new)
    assert_receive {:new_rendition_created, _}
    :ok = Playlist.append(context.playlist, TestSource.new)
    assert_receive {:new_rendition_created, _}
    {:ok, [rendition1, rendition2]} = Playlist.list(context.playlist)
    assert Enum.map(Rendition.all, fn(s) -> s.id end) == [rendition1.id, rendition2.id]

    Playlist.clear(context.playlist)

    Enum.each [rendition1, rendition2], fn(%Rendition{id: id}) ->
      assert_receive {:rendition_deleted, [^id, ^list_id]}
    end

    assert_receive {:playlist_cleared, [^list_id]}
    assert_receive {:"$__rendition_delete", [^list_id]}
    assert Rendition.all == []
  end
end
