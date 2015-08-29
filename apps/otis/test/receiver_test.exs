defmodule RecieversTest do
  use ExUnit.Case

  setup do
    {:ok, recs} = Otis.Receivers.start_link(:receivers_test)
    {:ok, recs: recs}
  end

  alias Otis.Receiver

  test "allows for the adding of a receiver", %{recs: recs} do
    {:ok, rec} = Receiver.start_link(:receiver_1, node)
    Otis.Receivers.add(recs, rec)
    {:ok, list } = Otis.Receivers.list(recs)
    assert list == [rec]
  end

  test "lets you retrieve a receiver by id", %{recs: recs} do
    {:ok, rec} = Receiver.start_link(:receiver_1, node)
    Otis.Receivers.add(recs, rec)
    {:ok, found } = Otis.Receivers.find(recs, "receiver_1")
    assert found == rec
  end

  test "lets you remove a receiver by id", %{recs: recs} do
    {:ok, rec} = Receiver.start_link(:receiver_1, node)
    Otis.Receivers.add(recs, rec)
    Otis.Receivers.remove(recs, rec)
    result = Otis.Receivers.find(recs, :receiver_1)
    assert result == :error
  end

  test "returns :error if given an invalid id", %{recs: recs} do
    result = Otis.Receivers.find(recs, "receiver-2")
    assert result == :error
  end
end

