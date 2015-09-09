defmodule Janis.Player.Socket do
  use     GenServer
  require Logger

  @moduledoc """
  Listens on a UDP multicast socket and passes all received packets onto
  a given instance of Janis.Player.Buffer.
  """

  @name Janis.Player.Socket

  def start_link({ip, port}, stream_info, buffer) do
    GenServer.start_link(__MODULE__, [{ip, port}, stream_info, buffer], name: @name)
  end

  def init([ {ip, port}, stream_info, buffer ]) do
    Logger.debug "Player.Socket up #{inspect {ip, port}}"
    {:ok, socket} = :gen_udp.open port, [:binary, active: true, ip: ip, add_membership: {ip, {0, 0, 0, 0}}, reuseaddr: true]
    # :ok = :gen_udp.controlling_process(socket, self)
    {:ok, {socket, buffer, stream_info}}
  end

  def handle_info({:udp, __socket, __addr, __port, data}, {_socket, buffer, _stream_info} = state) do
    {timestamp, _packet} = packet = :erlang.binary_to_term(data)
    Janis.Player.Buffer.put(buffer, packet)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug "Got message #{inspect msg}"
    {:noreply, state}
  end
end
