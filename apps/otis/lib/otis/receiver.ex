defmodule Otis.Receiver do
  use GenServer
  require Logger

  defmodule S do
    defstruct id: :receiver, node: nil, name: "Receiver", time_delta: nil, latency: nil
  end

  def id_from_node(node_name) do
    [name, _host] = Atom.to_string(node_name) |> String.split("@")
    String.to_atom(name)
  end

  def start_link(id, node) do
    GenServer.start_link(__MODULE__, %S{id: id, node: node}, name: id)
  end

  def init(state) do
    # Otis.Receiver.Monitor.start_link(id, node)
    {:ok, state}
  end
  #
  # def init(%S{node: node} = receiver) do
  #   IO.inspect [:init, node, self]
  #   Process.flag(:trap_exit, true)
  #   Process.link(node)
  #   {:ok, receiver}
  # end

  def id(pid) do
    GenServer.call(pid, :id)
  end

  def latency(pid) do
    GenServer.call(pid, :get_latency)
  end

  def receive_frame(pid, data, timestamp) do
    GenServer.cast(pid, {:receive_frame, data, timestamp})
  end

  def restore_state(pid, id) do
    Otis.State.restore_receiver(pid, id)
  end

  def join_zone(pid, zone) do
    GenServer.cast(pid, {:join_zone, zone})
  end

  def handle_call(:id, _from, %S{id: id} = receiver) do
    {:reply, {:ok, id}, receiver}
  end

  def handle_call(:get_latency, _from, %S{latency: latency} = receiver) do
    {:reply, {:ok, latency}, receiver}
  end

  def handle_cast({:receive_frame, data, timestamp}, %S{node: node} = rec) do
    timestamp = receiver_timestamp(rec, timestamp)
    deadline = timestamp + Otis.stream_interval_us
    GenServer.cast({Janis.Player, node}, {:play, data, timestamp, deadline})
    {:noreply, rec}
  end

  def handle_cast({:update_latency, latency}, %S{id: id, latency: nil} = state) do
    Logger.info "New player ready #{id}: latency: #{latency}"
    Otis.Receiver.restore_state(self, id)
    {:noreply, %S{state | latency: latency}}
  end

  def handle_cast({:update_latency, latency}, %S{latency: old_latency} = state) do
    l = Enum.max [latency, old_latency]
    Logger.debug "Update latency #{old_latency} -> #{latency} = #{l}"
    {:noreply, %S{state | latency: l}}
  end

  def handle_cast({:join_zone, zone}, %S{node: node} = state) do
    {:ok, {ip, port}} = Otis.Zone.broadcast_address(zone)
    Logger.debug "Receiver joining zone #{inspect {ip, port}} #{node}"
    # Now I want to send the ip:port info to the receiver which should cause it
    # to launch a player instance attached to that udp address (along with the
    # necessary linked processes)
    GenServer.cast({Janis.Monitor, node}, {:join_zone, {ip, port}})
    {:noreply, state}
  end

  def receiver_timestamp(%S{time_delta: time_delta} = _rec, player_timestamp) do
    player_timestamp + time_delta
  end

  # def terminate(reason, receiver) do
  #   IO.inspect [:receiver_terminate, reason]
  #   # Otis.Receivers.remove(Otis.Receivers, self)
  #   :ok
  # end
end
