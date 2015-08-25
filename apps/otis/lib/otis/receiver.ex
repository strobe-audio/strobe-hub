defmodule Otis.Receiver do
  use GenServer

  defstruct id: "receiver-1", name: "Receiver", conn: nil

  alias Otis.Receiver

  def start_link(id, name) do
    start_link(id, name, nil)
  end

  def start_link(id, name, conn) do
    GenServer.start_link(__MODULE__, %Receiver{id: id, name: name, conn: conn})
  end

  def init(%Receiver{conn: nil} = receiver) do
    {:ok, receiver}
  end

  def init(%Receiver{conn: conn} = receiver) do
    IO.inspect [:init, conn, self]
    Process.flag(:trap_exit, true)
    Process.link(conn)
    {:ok, receiver}
  end

  def id(pid) do
    GenServer.call(pid, :id)
  end

  def handle_call(:id, _from, %Receiver{id: id} = receiver) do
    {:reply, {:ok, id}, receiver}
  end

  def terminate(reason, receiver) do
    IO.inspect [:receiver_terminate, reason]
    # Otis.Receivers.remove(Otis.Receivers, self)
    :ok
  end
end
