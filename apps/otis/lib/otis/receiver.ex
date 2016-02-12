defmodule Otis.Receiver do
  use     GenServer
  require Logger

  defstruct [:id, :pid]

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

  def start_link(id, zone, config, channel, %{"latency" => latency} = _connection) do
    GenServer.start_link(__MODULE__, {id, zone, config, channel, latency}, name: receiver_register_name(id))
  end

  def init({id, zone, config, channel, latency} = args) do
    Logger.info "Starting receiver #{inspect(args)}"
    monitor = Process.monitor(channel)
    Process.flag(:trap_exit, true)
    state = %S{id: id,
      latency: latency,
      channel_monitor: monitor,
      zone: zone,
    }
    |> restore_state(config)
    |> join_zone
    {:ok, state}
  end

  def id!(%__MODULE__{id: id}) do
    id
  end
  def id!(pid) when is_pid(pid) do
    {:ok, id} = GenServer.call(pid, :id)
    id
  end

  def id(%__MODULE__{id: id}) do
    {:ok, id}
  end

  def id(pid) when is_pid(pid) do
    GenServer.call(pid, :id)
  end

  def latency(%__MODULE__{pid: pid}) do
    latency(pid)
  end
  def latency(receiver) when is_pid(receiver) do
    GenServer.call(receiver, :get_latency)
  end

  def restore_state(state, %{volume: volume} = _config) do
    %S{state | volume: volume}
  end

  def update_volume(%__MODULE__{pid: pid}) do
    update_volume(pid)
  end
  def update_volume(pid) when is_pid(pid) do
    GenServer.cast(pid, :update_volume)
  end

  def volume(%__MODULE__{pid: pid}) do
    volume(pid)
  end
  def volume(pid) when is_pid(pid) do
    GenServer.call(pid, :get_volume)
  end
  def volume(%__MODULE__{pid: pid}, volume) do
    volume(pid, volume)
  end
  def volume(pid, volume) when is_pid(pid) do
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

  def handle_cast({:set_volume, volume}, state) do
    state = state |> set_volume(volume)
    Otis.State.Events.notify({:receiver_volume_change, state.id, volume})
    {:noreply, state}
  end

  def handle_cast(:update_volume, %S{zone: zone, volume: volume} = state) do
    set_volume(state)
    {:noreply, state}
  end

  def handle_info({:DOWN, monitor, :process, _channel, :noproc}, %{channel_monitor: monitor} = state) do
    {:noreply, state}
  end

  # Refs to this receiver in zone & Receivers are removed by process monitor
  # callbacks so all we have to do is stop
  def handle_info({:DOWN, monitor, :process, _channel, reason}, %{channel_monitor: monitor} = state) do
    Logger.warn "Receiver disconnected... #{inspect reason}"
    {:stop, {:shutdown, :disconnect}, %S{state | channel_monitor: nil}}
  end

  defp set_volume(%S{ volume: volume } = state) do
    set_volume(state, volume)
  end
  defp set_volume(state, volume) do
    volume = Otis.sanitize_volume(volume)
    state = %S{ state | volume: volume }
    broadcast!(state, "set_volume", %{volume: calculated_volume(state)})
    state
  end

  defp calculated_volume(%S{volume: volume} = state) do
    {:ok, zone_volume} = Otis.Zone.volume(state.zone)
    Otis.sanitize_volume(volume * zone_volume)
  end

  def record(%S{id: id} = _state) do
    %__MODULE__{id: id, pid: self}
  end

  def join_zone(%S{zone: zone} = state) do
    {:ok, {port}} = Otis.Zone.broadcast_address(zone)
    broadcast!(state, "join_zone", %{
      port: port,
      interval: Otis.stream_interval_ms,
      size: Otis.stream_bytes_per_step,
      volume: calculated_volume(state)
    })
    Otis.Zone.add_receiver(zone, record(state))
    state
  end
  def terminate(_reason, _state) do
    :ok
  end

  defp broadcast!(state, event, msg) do
    Logger.debug "Sending event #{channel_name(state)} -> #{inspect event} :: #{ inspect msg }"
    Elvis.Endpoint.broadcast!(channel_name(state), event, msg)
  end

  defp channel_name(%S{id: id}) do
    "receiver:" <> id
  end
end
