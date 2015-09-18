defmodule Otis.Receiver do
  use     GenServer
  require Logger

  defmodule S do
    defstruct id: :"00-00-00-00-00-00",
              name: "Receiver",
              latency: nil,
              channel_monitor: nil,
              zone: nil
  end

  defp receiver_register_name(id) do
    "receiver-#{id}" |> String.to_atom
  end

  defp to_id(id_string) do
    String.to_atom(id_string)
  end

  def start_link(channel, id, %{"latency" => latency} = connection) do
    GenServer.start_link(__MODULE__, {channel, to_id(id), latency}, name: receiver_register_name(id))
  end

  def init({channel, id, latency}) do
    Logger.info "Starting receiver #{inspect(id)}; latency: #{latency}"
    monitor = Process.monitor(channel)
    Process.flag(:trap_exit, true)
    state = %S{id: id, latency: latency, channel_monitor: monitor}
    restore_state(self, id)
    {:ok, state}
  end

  def id(pid) do
    GenServer.call(pid, :id)
  end

  def latency(pid) do
    GenServer.call(pid, :get_latency)
  end

  def restore_state(pid, id) do
    Otis.State.restore_receiver(pid, id)
  end

  def join_zone(pid, zone) do
    GenServer.cast(pid, {:join_zone, zone})
  end

  def shutdown(pid) do
    GenServer.cast(pid, :shutdown)
  end

  def handle_call(:id, _from, %S{id: id} = receiver) do
    {:reply, {:ok, id}, receiver}
  end

  def handle_call(:get_latency, _from, %S{latency: latency} = receiver) do
    {:reply, {:ok, latency}, receiver}
  end

  def handle_cast({:update_latency, latency}, %S{id: id, latency: nil} = state) do
    Logger.info "New player ready #{id}: latency: #{latency}"
    {:noreply, %S{state | latency: latency}}
  end

  def handle_cast({:update_latency, latency}, %S{latency: old_latency} = state) do
    l = Enum.max [latency, old_latency]
    # Logger.debug "Update latency #{old_latency} -> #{latency} = #{l}"
    {:noreply, %S{state | latency: l}}
  end

  def handle_cast({:join_zone, zone}, %S{id: id} = state) do
    {:ok, {ip, port}} = Otis.Zone.broadcast_address(zone)
    # Now I want to send the ip:port info to the receiver which should cause it
    # to launch a player instance attached to that udp address (along with the
    # necessary linked processes)
    # GenServer.cast({Janis.Monitor, node}, {:join_zone, {ip, port}, Otis.stream_interval_ms, Otis.stream_bytes_per_step})
    channel = "receiver:" <> Atom.to_string(id)
    Logger.debug "Receiver joining zone #{inspect {ip, port}} #{channel}"
    Elvis.Endpoint.broadcast!(channel, "join_zone", %{address: Tuple.to_list(ip), port: port, interval: Otis.stream_interval_ms, size: Otis.stream_bytes_per_step})
    {:noreply, %S{ state | zone: zone }}
  end

  def handle_cast(:shutdown, %S{id: id, zone: zone} = state) do
    Logger.warn "Receiver shutting down #{id}"
    Otis.Zone.remove_receiver(zone, self)
    {:stop, :shutdown, state}
  end

  def handle_info({:DOWN, monitor, :process, _channel, :noproc}, %{channel_monitor: monitor} = state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, monitor, :process, _channel, reason}, %{channel_monitor: monitor} = state) do
    Logger.warn "Receiver disconnected... #{inspect reason}"
    Otis.Receivers.remove(self)
    {:noreply, state}
  end

  def terminate(reason, %S{channel_monitor: monitor} = state) do
    IO.inspect [:receiver_terminate, reason]
    :ok
  end
end
