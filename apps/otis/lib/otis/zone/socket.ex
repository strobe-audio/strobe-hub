defmodule Otis.Zone.Socket do
  use GenServer
  require Logger

  def start_link(address) do
    GenServer.start_link(__MODULE__, address, [])
  end

  def init({ip, port} = _address) do
    Logger.debug "Starting socket with ip #{inspect ip}:#{port}"
    {:ok, socket} = :gen_udp.open 0, [:binary, ip: {0, 0, 0, 0}, multicast_ttl: 255, reuseaddr: true]
    {:ok, {socket, ip, port, 1}}
  end

  def send(pid, timestamp, data) do
    GenServer.cast(pid, {:send, timestamp, data})
  end

  def handle_cast({:send, timestamp, audio}, {socket, ip, port, count} = state) do
    packet = << count::size(64)-little-unsigned-integer, timestamp::size(64)-little-signed-integer, audio::binary >>
    :gen_udp.send socket,  ip, port, packet
    {:noreply, {socket, ip, port, count + 1}}
  end
end
