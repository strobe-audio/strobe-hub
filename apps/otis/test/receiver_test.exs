defmodule RecieversTest do
  use ExUnit.Case

  setup do
    {:ok, recs} = Otis.Receivers.start_link(:receivers_test)
    on_exit fn ->
      Process.exit(recs, :kill)
    end
    {:ok, recs: recs}
  end

  test "allows for the adding of a receiver", %{recs: recs} do
    {:ok, rec} = Otis.Receiver.start_link(self, "receiver_1", %{ "latency" => 0 })
    Otis.Receivers.add(recs, rec)
    {:ok, list } = Otis.Receivers.list(recs)
    assert list == [rec]
  end

  test "lets you retrieve a receiver by id", %{recs: recs} do
    {:ok, rec} = Otis.Receiver.start_link(self, "receiver_2", %{ "latency" => 0 })
    Otis.Receivers.add(recs, rec)
    {:ok, found } = Otis.Receivers.find(recs, "receiver_2")
    assert found == rec
  end

  test "lets you remove a receiver by id", %{recs: recs} do
    {:ok, rec} = Otis.Receiver.start_link(self, "receiver_3", %{ "latency" => 0 })
    Otis.Receivers.add(recs, rec)
    Otis.Receivers.remove(recs, rec)
    result = Otis.Receivers.find(recs, "receiver_3")
    assert result == {:error, :not_found}
  end

  test "returns :error if given an invalid id", %{recs: recs} do
    result = Otis.Receivers.find(recs, "receiver-2")
    assert result == {:error, :not_found}
  end
end

