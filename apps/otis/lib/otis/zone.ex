defmodule Otis.Zone do
  use     GenServer
  require Logger

  defmodule S do
    defstruct [
      id:                nil,
      source_list:       nil,
      receivers:         HashSet.new,
      state:             :stop,
      broadcaster:       nil,
      clock:             nil,
      audio_stream:      nil,
      broadcast_address: nil,
      socket:            nil,
      volume:            1.0,
    ]
  end

  defstruct [:id, :pid]

  # music starts playing after this many microseconds
  @buffer_latency     50_000
  @buffer_size        25

  def start_link(id, config) do
    start_link(id, config, Otis.SourceList.empty(id))
  end

  def start_link(id, config, {:ok, source_list}) do
    start_link(id, config, source_list)
  end

  def start_link(id, config, source_list) do
    GenServer.start_link(__MODULE__, {id, config, source_list}, name: String.to_atom("zone-#{id}"))
  end

  def init({id, config, source_list}) do
    Logger.info "#{__MODULE__} starting... #{ id }"
    {:ok, port} = Otis.PortSequence.next
    {:ok, socket} = Otis.Zone.Socket.start_link(port)
    {:ok, audio_stream } = Otis.AudioStream.start_link(source_list, Otis.stream_bytes_per_step)
    {:ok, stream} = Otis.Zone.BufferedStream.seconds(audio_stream, 1)
    {:ok, %S{
        id: id,
        source_list: source_list,
        audio_stream: stream,
        socket: socket,
        broadcast_address: {port},
        volume: config.volume
      }
    }
  end

  def get_broadcast_address do
    case Otis.IPPool.next_address do
      {:ok, ip, port} -> {ip, port}
      _ = response -> raise "bad ip #{inspect response}"
    end
  end

  def id(zone) do
    GenServer.call(zone, :id)
  end

  def receivers(zone) do
    GenServer.call(zone, :receivers)
  end

  def add_receiver(%__MODULE__{pid: pid} = _zone, receiver) do
    add_receiver(pid, receiver)
  end
  def add_receiver(zone, receiver) when is_pid(zone) do
    GenServer.call(zone, {:add_receiver, receiver})
  end

  def state(zone) do
    GenServer.call(zone, :get_state)
  end

  def play_pause(zone) do
    GenServer.call(zone, :play_pause)
  end

  def source_list(zone) do
    GenServer.call(zone, :get_source_list)
  end

  def audio_stream(zone) do
    GenServer.call(zone, :get_audio_stream)
  end

  def broadcast_address(%__MODULE__{pid: pid} = _zone) do
    broadcast_address(pid)
  end

  def broadcast_address(zone) when is_pid(zone) do
    GenServer.call(zone, :get_broadcast_address)
  end

  def volume(%__MODULE__{pid: pid}) do
    volume(pid)
  end
  def volume(zone) when is_pid(zone) do
    GenServer.call(zone, :volume)
  end
  def volume(%__MODULE__{pid: pid}, volume) do
    volume(pid, volume)
  end
  def volume(zone, volume) when is_pid(zone) do
    GenServer.call(zone, {:volume, volume})
  end

  @doc "Called by the broadcaster in order to keep our state in sync"
  def stream_finished(zone) do
    GenServer.cast(zone, :stream_finished)
  end

  @doc "Skip to the source with the given id"
  def skip(zone, id) do
    GenServer.cast(zone, {:skip, id})
  end

  # Things we can do to zones:
  # - list receivers
  # - add receiver
  # - remove receiver
  # - change source stream
  # - on the attached source stream:
  #   - add/remove sources
  #   - re-order sources
  #   - change position in source stream (skip track)
  # - get playing state
  # - start / stop
  # - change volume (?)

  # add sources play next
  # add sources play now
  # append sources
  # skip track
  # rewind track

  def handle_call(:id, _from, %S{id: id} = zone) do
    {:reply, {:ok, id}, zone}
  end

  def handle_call(:receivers, _from, %S{receivers: receivers} = zone) do
    {:reply, {:ok, Set.to_list(receivers)}, zone}
  end

  def handle_call({:add_receiver, receiver}, _from, %S{id: id} = zone) do
    Logger.info "Adding receiver to zone #{id} #{inspect receiver}"
    zone = receiver_joined(receiver, zone)
    {:reply, :ok, zone}
  end

  def handle_call(:play_pause, _from, zone) do
    zone = zone |> toggle_state
    {:reply, {:ok, zone.state}, zone}
  end

  def handle_call(:get_state, _from, %S{state: state} = zone) do
    {:reply, {:ok, state}, zone}
  end

  def handle_call(:get_audio_stream, _from, %S{audio_stream: audio_stream} = zone) do
    {:reply, {:ok, audio_stream}, zone}
  end

  def handle_call(:get_source_list, _from, %S{source_list: source_list} = zone) do
    {:reply, {:ok, source_list}, zone}
  end

  def handle_call(:get_broadcast_address, _from, %S{broadcast_address: broadcast_address} = zone) do
    {:reply, {:ok, broadcast_address}, zone}
  end
  def handle_call(:volume, _from, %S{volume: volume} = zone) do
    {:reply, {:ok, volume}, zone}
  end
  def handle_call({:volume, volume}, _from, zone) do
    volume = Otis.sanitize_volume(volume)
    Otis.State.Events.notify({:zone_volume_change, zone.id, volume})
    {:reply, {:ok, volume}, %S{zone | volume: volume}}
  end

  def handle_cast(:stream_finished, zone) do
    {:noreply, stream_finished!(zone)}
  end

  # TODO: handle the case where we skip past the end of the source list...
  def handle_cast({:skip, id}, zone) do
    zone = zone |> set_state(:skip) |> flush |> skip_to(id)
    {:noreply, set_state(zone, :play)}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state = receiver_shutdown(state, pid, Set.to_list(state.receivers))
    {:noreply, state}
  end

  def receiver_shutdown(state, pid, []) do
    Logger.warn "Unknown receiver shutdown #{ inspect pid } #{ inspect Set.to_list(state.receivers)}"
    state
  end
  def receiver_shutdown(state, pid, [%Otis.Receiver{pid: pid} = receiver | _receivers]) do
    %S{ state | receivers: Set.delete(state.receivers, receiver) }
  end
  def receiver_shutdown(state, pid, [_ | receivers]) do
    receiver_shutdown(state, pid, receivers)
  end

  defp flush(zone) do
    Otis.Stream.flush(zone.audio_stream)
    zone
  end

  defp skip_to(zone, id) do
    {:ok, _} = Otis.SourceList.skip(zone.source_list, id)
    zone
  end

  defp receiver_joined(receiver, %S{state: :play, broadcaster: broadcaster} = zone) do
    Otis.Zone.Broadcaster.buffer_receiver(broadcaster)
    add_receiver_to_zone(receiver, zone)
  end

  defp receiver_joined(receiver, %S{state: :stop} = zone) do
    add_receiver_to_zone(receiver, zone)
  end

  defp add_receiver_to_zone(receiver, %S{receivers: receivers} = zone) do
    Process.monitor(receiver.pid)
    event!(:receiver_added, {Otis.Receiver.id!(receiver)}, zone)
    %S{ zone | receivers: Set.put(receivers, receiver) }
  end

  defp event!(name, params, zone) do
    Otis.State.Events.notify({name, zone.id, params})
  end

  def receiver_latency(%S{receivers: %HashSet{} = recs}) do
    _receiver_latency(Set.to_list(recs))
  end

  defp _receiver_latency([]) do
    Logger.warn "No receivers attached to zone..."
    0
  end

  defp _receiver_latency(recs) do
    recs |> Enum.map(fn(rec) ->
      {:ok, latency} = Otis.Receiver.latency(rec)
      latency
    end) |> Enum.max
  end

  defp stream_finished!(zone) do
    zone |> stream_has_finished |> set_state(:stop)
  end

  defp stream_has_finished(%S{broadcaster: nil} = zone) do
    zone
  end
  defp stream_has_finished(zone) do
    Otis.Broadcaster.Controller.done(zone.clock)
    %S{zone | broadcaster: nil}
  end

  defp toggle_state(%S{state: :play} = zone) do
    set_state(zone, :stop)
  end

  defp toggle_state(%S{state: :stop} = zone) do
    set_state(zone, :play)
  end

  defp set_state(zone, state) do
    %S{ zone | state: state } |> change_state
  end

  defp change_state(%S{state: :play, clock: nil} = zone) do
    # TODO: share a clock between all zones
    clock = Otis.Zone.Controller.new(Otis.stream_interval_us)
    %S{ zone | clock: clock } |> change_state
  end
  defp change_state(%S{state: :play, broadcaster: nil, clock: clock} = zone) do
    {:ok, broadcaster} = start_broadcaster(zone)
    clock = Otis.Broadcaster.Controller.start(clock, broadcaster, broadcaster_latency(zone), @buffer_size)
    %S{ zone | broadcaster: broadcaster, clock: clock }
  end
  defp change_state(%S{state: :play} = zone) do
    zone
  end
  defp change_state(%S{state: :stop, broadcaster: nil} = zone) do
    Logger.debug("Zone stopped")
    zone_is_stopped(zone)
  end
  defp change_state(%S{state: :stop, broadcaster: broadcaster} = zone) do
    clock = Otis.Broadcaster.Controller.stop(zone.clock, broadcaster)
    change_state(%S{ zone | broadcaster: nil, clock: clock })
  end
  defp change_state(%S{state: :skip, broadcaster: nil} = zone) do
    zone
  end
  defp change_state(%S{id: _id, state: :skip, broadcaster: broadcaster} = zone) do
    clock = Otis.Broadcaster.Controller.skip(zone.clock, broadcaster)
    change_state(%S{ zone | broadcaster: nil, clock: clock })
  end

  defp broadcaster_latency(zone) do
    receiver_latency(zone) + @buffer_latency
  end

  defp zone_is_stopped(zone) do
    Otis.Stream.reset(zone.audio_stream)
    %S{ zone | broadcaster: nil}
  end

  defp start_broadcaster(%S{id: id, audio_stream: audio_stream, socket: socket}) do
    opts = %{
      id: id,
      zone: self,
      audio_stream: audio_stream,
      emitter: Otis.Zone.Emitter.new(socket),
      stream_interval: Otis.stream_interval_us
    }
    Otis.Broadcaster.start_broadcaster(opts)
  end
end