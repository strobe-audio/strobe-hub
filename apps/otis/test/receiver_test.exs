defmodule RecieversTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, recs} = Otis.Receivers.start_link
    {:ok, conn} = FakeConnection.start_link
    {:ok, recs: recs, conn: conn}
  end

  alias Otis.Receiver

  test "allows for the adding of a receiver", %{recs: recs, conn: conn} do
    {:ok, rec} = Receiver.start_link("receiver-1", "Downstairs", conn)
    Otis.Receivers.add(recs, rec)
    {:ok, list } = Otis.Receivers.list(recs)
    assert list == [rec]
  end

  test "lets you retrieve a receiver by id", %{recs: recs, conn: conn} do
    {:ok, rec} = Receiver.start_link("receiver-1", "Downstairs", conn)
    Otis.Receivers.add(recs, rec)
    {:ok, found } = Otis.Receivers.find(recs, "receiver-1")
    assert found == rec
  end

  test "lets you remove a receiver by id", %{recs: recs, conn: conn} do
    {:ok, rec} = Receiver.start_link("receiver-1", "Downstairs", conn)
    Otis.Receivers.add(recs, rec)
    Otis.Receivers.remove(recs, rec)
    result = Otis.Receivers.find(recs, "receiver-1")
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

  def terminate(reason, state) do
    IO.inspect [:conn_terminate, reason]
    :ok
  end
end
defmodule ReceiverTest do
  use ExUnit.Case, async: true

  alias Otis.Receiver

  setup do
    {:ok, recs} = Otis.Receivers.start_link(name: Otis.Receivers)
    {:ok, conn} = FakeConnection.start
    {:ok, rec} = Receiver.start_link("receiver-1", "Downstairs", conn)
    Otis.Receivers.add(recs, rec)
    {:ok, recs: recs, rec: rec, conn: conn}
  end

  test "stops the receiver process when the connection ends", %{recs: recs, rec: rec, conn: conn} do
    assert Process.alive?(conn)
    assert Process.alive?(rec)

    Process.exit(conn, :shutdown)
    assert Process.alive?(conn) == false
    result = Otis.Receivers.find(recs, "receiver-1")
    assert result == :error
  end
end
