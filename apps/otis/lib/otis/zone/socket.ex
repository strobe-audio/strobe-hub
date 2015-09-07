defmodule Otis.Zone.Socket do
  use GenServer
  require Logger

  def start_link(address) do
    GenServer.start_link(__MODULE__, address, [])
  end

  def init({ip, port} = _address) do
    Logger.debug "Starting socket with ip #{inspect ip}:#{port}"
    {:ok, socket} = :gen_udp.open 0, [:binary, ip: {0, 0, 0, 0}, multicast_ttl: 255, reuseaddr: true]
    {:ok, {socket, ip, port}}
  end

  def send(pid, timestamp, data) do
    GenServer.cast(pid, {:send, timestamp, data})
  end

  def handle_cast({:send, timestamp, data}, {socket, ip, port} = state) do
    packet = :erlang.term_to_binary({timestamp, data})
    :gen_udp.send socket,  ip, port, packet
    {:noreply, state}
  end
end
