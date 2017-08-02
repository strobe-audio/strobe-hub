defmodule Otis.Receivers.Logger do
  @moduledoc """
  Listens for UDP log events from the receivers and forwards them onto the
  configured UDP port.
  """

  use     GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    config = Application.get_env(:otis, :receiver_logger)
    Logger.info "Starting multicast logging on #{inspect config[:addr]}:#{config[:port]}"
    {:ok,socket} = :gen_udp.open(config[:port], [:binary, reuseaddr: true, ip: config[:addr], multicast_ttl: 4, multicast_loop: false, active: true])
    :inet.setopts(socket,[add_membership: {config[:addr],{0,0,0,0}}])
    {:ok, %{socket: socket, config: config}}
  end

  def handle_info({:udp, _socket, _addr, _port, _msg}, state) do
    # ip = addr |> Tuple.to_list |> Enum.join(".")
    #   Logger.log(:info, String.trim_trailing(msg), [ip: ip])
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn "Unhandled message #{inspect msg}"
    {:noreply, state}
  end

  def terminate(_reason, %{socket: socket}) do
    Logger.info "Closing socket"
    :gen_udp.close(socket)
    :ok
  end
end
