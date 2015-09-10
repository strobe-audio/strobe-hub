
defmodule Otis.SNTP do
  require Logger

  @name Otis.SNTP

  def start_link(port \\ 9104) do
    :proc_lib.start_link(__MODULE__, :init, [port])
  end

  def init(port) do
    Logger.info "Starting SNTP server on port #{port}"
    :erlang.register(@name, self)
    Process.flag(:trap_exit, true)
    :proc_lib.init_ack({:ok, self})
    {:ok, socket} = :gen_udp.open port, [mode: :binary, ip: {0, 0, 0, 0}, active: false]
    state = {socket}
    loop(state)
  end

  def loop({socket} = state) do
    receive do
    after 0 ->
      case :gen_udp.recv(socket, 0) do
        {:ok, {address, port, packet}} ->
          reply(socket, address, port, packet, now)
        {:error, reason} ->
          Logger.warn "SNTP got error #{inspect reason}"
      end
    end
    loop(state)
  end

  def reply(socket, address, port, packet, receive_ts) do
    # Logger.debug "Got sync request from #{inspect address}:#{port}"
    << count::size(64)-little-unsigned-integer,
       originate_ts::size(64)-little-signed-integer
    >> = packet
    # IO.inspect [count, now]
    reply = <<
      count::size(64)-little-unsigned-integer,
      originate_ts::size(64)-little-signed-integer,
      receive_ts::size(64)-little-signed-integer,
      now::size(64)-little-signed-integer
    >>
    :gen_udp.send socket, address, port, reply
  end

  def now do
    :erlang.monotonic_time :micro_seconds
  end
end

