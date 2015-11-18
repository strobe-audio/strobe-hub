defmodule Otis.Zone.Socket do
  use GenServer
  require Logger

  def start_link(address) do
    GenServer.start_link(__MODULE__, address, [])
  end

  def init(port) do
    Logger.debug "Starting socket with address #{bind(port)}"
    {:ok, socket} = :enm.pub(bind: bind(port), nodelay: true)
    {:ok, {socket, port, 1}}
  end

  def bind(port) do
    "tcp://*:#{port}"
  end

  def send(pid, timestamp, data) do
    GenServer.cast(pid, {:send, timestamp, data})
  end

  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  def handle_cast({:send, timestamp, audio}, {socket, port, count} = _state) do
    packet = <<
      count     :: size(64)-little-unsigned-integer,
      timestamp :: size(64)-little-signed-integer,
      audio     :: binary
    >>
    _send(socket, packet)
    {:noreply, {socket, port, count + 1}}
  end

  def handle_cast(:stop, {socket, port, count} = _state) do
    _send(socket, <<"STOP">>)
    {:noreply, {socket, port, count + 1}}
  end

  defp _send(socket, data) do
    :enm.send(socket, data)
  end
end
