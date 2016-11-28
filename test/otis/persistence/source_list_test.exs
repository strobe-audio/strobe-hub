defmodule Otis.Persistence.SourceListTest do
  use   ExUnit.Case
  alias Otis.Test.TestSource

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach
    id = Otis.uuid
    {:ok, source_list} = Otis.SourceList.empty(id)

    {:ok, id: id, source_list: source_list}
  end

  test "emits events  when cleared", %{id: list_id} = context do
    {:ok, 1} = Otis.SourceList.append(context.source_list, TestSource.new)
    assert_receive {:new_rendition_created, _}
    {:ok, 2} = Otis.SourceList.append(context.source_list, TestSource.new)
    assert_receive {:new_rendition_created, _}
    {:ok, [entry1, entry2]} = Otis.SourceList.list(context.source_list)

    Otis.SourceList.clear(context.source_list)

    Enum.each [entry1, entry2], fn({rendition_id, 0, _rendition}) ->
      assert_receive {:rendition_deleted, [^rendition_id, ^list_id]}
    end

    assert_receive {:source_list_cleared, [^list_id]}
  end

  test "deletes the matching db entries when cleared", %{id: list_id} = context do
    {:ok, 1} = Otis.SourceList.append(context.source_list, TestSource.new)
    assert_receive {:new_rendition_created, _}
    {:ok, 2} = Otis.SourceList.append(context.source_list, TestSource.new)
    assert_receive {:new_rendition_created, _}
    {:ok, [{id1, _, _}, {id2, _, _}]} = Otis.SourceList.list(context.source_list)
    assert Enum.map(Otis.State.Rendition.all, fn(s) -> s.id end) == [id1, id2]

    Otis.SourceList.clear(context.source_list)

    Enum.each [id1, id2], fn(id) ->
      assert_receive {:rendition_deleted, [^id, ^list_id]}
    end

    assert_receive {:source_list_cleared, [^list_id]}
    assert Otis.State.Rendition.all == []
  end
end
