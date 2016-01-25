defmodule Otis.Receiver do
  use     GenServer
  require Logger

  defmodule S do
    defstruct id: :"00-00-00-00-00-00",
              name: "Receiver",
              latency: nil,
              channel_monitor: nil,
              zone: nil,
              volume: 1.0
  end

  defp receiver_register_name(id) do
    "receiver-#{id}" |> String.to_atom
  end

  defp to_id(id_string) do
    String.to_atom(id_string)
  end

  def start_link(channel, id, %{"latency" => latency} = _connection) do
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

  def id!(pid) do
    {:ok, id} = GenServer.call(pid, :id)
    id
  end

  def latency(pid) do
    GenServer.call(pid, :get_latency)
  end

  def restore_state(pid, id) do
    Otis.State.restore_receiver(pid, id)
  end

  def join_zone(pid, zone, broadcast_address) do
    GenServer.cast(pid, {:join_zone, zone, broadcast_address})
  end

  def shutdown(pid) do
    GenServer.cast(pid, :shutdown)
  end

  def volume(pid) do
    GenServer.call(pid, :get_volume)
  end

  def volume(pid, volume) do
    GenServer.cast(pid, {:set_volume, volume})
  end

  def handle_call(:id, _from, %S{id: id} = receiver) do
    {:reply, {:ok, id}, receiver}
  end

  def handle_call(:get_latency, _from, %S{latency: latency} = receiver) do
    {:reply, {:ok, latency}, receiver}
  end

  def handle_call(:get_volume, _from, %S{volume: volume} = receiver) do
    {:reply, {:ok, volume}, receiver}
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

  def handle_cast({:join_zone, zone, {port}}, state) do
    # {:ok, {port}} = Otis.Zone.broadcast_address(zone)
    # Now I want to send the ip:port info to the receiver which should cause it
    # to launch a player instance attached to that udp address (along with the
    # necessary linked processes)
    broadcast!(state, "join_zone", %{
      port: port,
      interval: Otis.stream_interval_ms,
      size: Otis.stream_bytes_per_step,
      volume: 0.5
    })
    {:noreply, %S{ state | zone: zone }}
  end

  def handle_cast({:set_volume, volume}, state) do
    volume = sanitize_volume(volume)
    broadcast!(state, "set_volume", %{volume: volume})
    {:noreply, %S{ state | volume: volume }}
  end


  def handle_cast(:shutdown, %S{id: id, zone: zone} = state) do
    Logger.warn "Receiver shutting down #{id}"
    remove_from_zone(zone)
    {:stop, :shutdown, %S{state | zone: nil}}
  end

  def handle_info({:DOWN, monitor, :process, _channel, :noproc}, %{channel_monitor: monitor} = state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, monitor, :process, _channel, reason}, %{channel_monitor: monitor} = state) do
    Logger.warn "Receiver disconnected... #{inspect reason}"
    Otis.Receivers.remove(self)
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp remove_from_zone(nil) do
  end
  defp remove_from_zone(zone) do
    Otis.Zone.remove_receiver(zone, self)
  end

  defp broadcast!(state, event, msg) do
    Logger.debug "Sending event #{channel_name(state)} -> #{inspect event} :: #{ inspect msg }"
    Elvis.Endpoint.broadcast!(channel_name(state), event, msg)
  end

  defp channel_name(%S{id: id}) do
    "receiver:" <> Atom.to_string(id)
  end

  defp sanitize_volume(volume) when volume > 1.0 do
    1.0
  end
  defp sanitize_volume(volume) when volume < 0.0 do
    0.0
  end
  defp sanitize_volume(volume) do
    volume
  end
end
