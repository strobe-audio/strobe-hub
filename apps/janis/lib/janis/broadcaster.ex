defmodule Janis.Broadcaster do
  use GenServer
  require Logger

  @name  Janis.Broadcaster

  def start_link(node_name) do
    GenServer.start_link(__MODULE__, node_name, name: @name)
  end

  def init(node_name) do
    Logger.debug "Starting broadcaster  #{node_name}"
    {:ok, monitor} = Janis.Monitor.start_link(self)
    # FIXME: get port from broadcaster somehow...
    {:ok, %{broadcaster: node_name, monitor: monitor, address: address(node_name), port: 9104, sync_count: 0}}
  end

  defp address(node_name) do
    {:ok, address} = Atom.to_string(node_name)
                      |> String.split("@")
                      |> List.last
                      |> String.to_char_list
                      |> :inet.parse_ipv4_address
    address
  end

  def handle_cast({:receiver_latency, latency}, %{broadcaster: broadcaster} = state) do
    # Logger.debug "Broadcaster new latency #{latency} #{inspect broadcaster}"
    GenServer.cast({Otis.Receivers, broadcaster}, {:receiver_latency, node, latency})
    {:noreply, state}
  end

  def handle_call(:measure_latency, _from, %{address: address, port: port, sync_count: count} = state) do
    {:ok, socket} = :gen_udp.open 0, [mode: :binary, ip: {0, 0, 0, 0}, active: false]
    packet = <<
      count::size(64)-little-unsigned-integer,
      Janis.microseconds::size(64)-little-signed-integer
    >>
    :ok = :gen_udp.send socket, address, port, packet

    {:ok, {originate, receipt, reply, finish}} = wait_response(socket)
    :ok = :gen_udp.close(socket)
    {:reply, {:ok, {originate, receipt, reply, finish}}, %{state | sync_count: count + 1}}
  end

  defp wait_response(socket) do
    receive do
    after 0 ->
      :gen_udp.recv(socket, 0, 1000) |> parse_response
    end
  end

  defp parse_response({:ok, {_addr, _port, data}}) do
    now = Janis.microseconds
    << count::size(64)-little-unsigned-integer,
       originate::size(64)-little-signed-integer,
       receipt::size(64)-little-signed-integer,
       reply::size(64)-little-signed-integer
    >> = data
    # IO.inspect [count, originate, receipt, reply, now]
    {:ok, {originate, receipt, reply, now}}
  end

  # def handle_call(:measure_latency, _from, %{broadcaster: broadcaster} = state) do
  #   IO.inspect [:measure_latency, broadcaster]
  #   start = Janis.microseconds
  #   response = GenServer.call({Otis.Receivers, broadcaster}, {:time_sync, {start}})
  #   {:ok, {_start, receipt}} = response
  #   finish = Janis.microseconds
  #   {:reply, {:ok, {start, receipt, finish}}, state}
  # end

  def terminate(_reason, _state) do
    :ok
  end
end
