defmodule RecieversTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, monitor} = FakeMonitor.start
    {:ok, recs} = Otis.Receivers.start_link(:receivers_test)
    {:ok, recs: recs, monitor: monitor}
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

defmodule FakeConnection do
  use GenServer
  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def start do
    GenServer.start(__MODULE__, :ok, [])
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def handle_call(:stop, _from, state) do
    # IO.inspect [:stopping_conn]
    {:stop, :normal, :ok, state}
  end

  def terminate(reason, _state) do
    IO.inspect [:conn_terminate, reason]
    :ok
  end
end
