defmodule Otis.Zone do
  use     GenServer
  require Logger
  alias   Otis.Receiver, as: Receiver

  defmodule S do
    @moduledoc "The state struct for Zone processes"
    defstruct [
      id:                nil,
      source_list:       nil,
      receivers:         MapSet.new,
      state:             :stop,
      broadcaster:       nil,
      ctrl:              nil,
      audio_stream:      nil,
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
    {:ok, socket} = Otis.Zone.Socket.start_link(id)
    {:ok, audio_stream } = Otis.AudioStream.start_link(source_list, Otis.stream_bytes_per_step)
    {:ok, stream} = Otis.Zone.BufferedStream.seconds(audio_stream, 1)
    {:ok, %S{
        id: id,
        source_list: source_list,
        audio_stream: stream,
        socket: socket,
        volume: Map.get(config, :volume, 1.0)
      }
    }
  end

  def id(%__MODULE__{id: id}) do
    {:ok, id}
  end
  def id(zone) do
    GenServer.call(zone, :id)
  end

  def receivers(%__MODULE__{pid: pid} = _zone) do
    receivers(pid)
  end
  def receivers(zone) do
    GenServer.call(zone, :receivers)
  end

  def socket(%__MODULE__{pid: pid} = _zone) do
    socket(pid)
  end
  def socket(zone) do
    GenServer.call(zone, :socket)
  end

  def add_receiver(%__MODULE__{pid: pid} = _zone, receiver) do
    add_receiver(pid, receiver)
  end
  def add_receiver(zone, receiver) when is_pid(zone) do
    GenServer.call(zone, {:add_receiver, receiver})
  end

  def remove_receiver(%__MODULE__{pid: pid} = _zone, receiver) do
    remove_receiver(pid, receiver)
  end
  def remove_receiver(zone, receiver) when is_pid(zone) do
    GenServer.cast(zone, {:remove_receiver, receiver})
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

  def volume!(zone) do
    {:ok, volume} = volume(zone)
    volume
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

  def receiver_buffered(zone, receiver) do
    GenServer.cast(zone, {:receiver_buffered, receiver})
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

  def handle_call(:id, _from, %S{id: id} = state) do
    {:reply, {:ok, id}, state}
  end

  def handle_call(:receivers, _from, %S{receivers: receivers} = state) do
    {:reply, {:ok, Set.to_list(receivers)}, state}
  end

  def handle_call(:socket, _from, %S{socket: socket} = state) do
    {:reply, {:ok, socket}, state}
  end

  def handle_call({:add_receiver, receiver}, _from, %S{id: id} = state) do
    Logger.info "Adding receiver to zone #{id} #{inspect receiver}"
    state = add_receiver_to_zone(receiver, state)
    {:reply, :ok, state}
  end

  def handle_call(:play_pause, _from, state) do
    state = state |> toggle_state
    {:reply, {:ok, state.state}, state}
  end

  def handle_call(:get_state, _from, %S{state: state} = state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call(:get_audio_stream, _from, %S{audio_stream: audio_stream} = state) do
    {:reply, {:ok, audio_stream}, state}
  end

  def handle_call(:get_source_list, _from, %S{source_list: source_list} = state) do
    {:reply, {:ok, source_list}, state}
  end

  def handle_call(:volume, _from, %S{volume: volume} = state) do
    {:reply, {:ok, volume}, state}
  end
  def handle_call({:volume, volume}, _from, state) do
    volume = Otis.sanitize_volume(volume)
    Enum.each(state.receivers, &Receiver.volume_multiplier(&1, volume))
    Otis.State.Events.notify({:zone_volume_change, state.id, volume})
    {:reply, {:ok, volume}, %S{state | volume: volume}}
  end

  def handle_cast(:stream_finished, state) do
    {:noreply, stream_finished!(state)}
  end

  # TODO: handle the case where we skip past the end of the source list...
  def handle_cast({:skip, id}, state) do
    state = state |> set_state(:skip) |> flush |> skip_to(id) |> set_state(:play)
    {:noreply, state}
  end

  # Called by the broadcaster when it has finished sending in-flight packets.
  def handle_cast({:receiver_buffered, receiver}, state) do
    state = receiver_ready(receiver, state)
    {:noreply, state}
  end

  def handle_cast({:remove_receiver, receiver}, %S{id: id} = state) do
    Logger.info "Removing receiver from zone #{id} #{inspect receiver}"
    state = remove_receiver_from_zone(receiver, state)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state = Receiver.matching_pid(state.receivers, pid) |> receiver_shutdown(state)
    {:noreply, state}
  end

  def receiver_shutdown(nil, state) do
    state
  end
  def receiver_shutdown(receiver, state) do
    %S{ state | receivers: MapSet.delete(state.receivers, receiver) }
  end

  defp flush(state) do
    Otis.Stream.flush(state.audio_stream)
    state
  end

  defp skip_to(state, id) do
    {:ok, _} = Otis.SourceList.skip(state.source_list, id)
    state
  end

  defp add_receiver_to_zone(receiver, %S{state: :play, broadcaster: broadcaster} = state) do
    adopt_receiver(receiver, state)
    Otis.Zone.Broadcaster.buffer_receiver(broadcaster, self, receiver)
    state
  end

  defp add_receiver_to_zone(receiver, %S{state: :stop} = state) do
    adopt_receiver(receiver, state)
    receiver_ready(receiver, state)
  end

  defp remove_receiver_from_zone(receiver, state) do
    receivers = MapSet.delete(state.receivers, receiver)
    if MapSet.member?(state.receivers, receiver) do
      Otis.Zone.Socket.remove_receiver(state.socket, receiver)
      event!(state, :receiver_removed, Receiver.id!(receiver))
    end
    %S{ state | receivers: receivers }
  end

  defp adopt_receiver(receiver, state) do
    Otis.Zones.release_receiver(receiver, self)
    Receiver.monitor(receiver)
    Receiver.volume_multiplier(receiver, state.volume)
    # I have to add the receiver to the socket here because the quick-buffering
    # system needs to send the packets to the receiver immediately.
    Otis.Zone.Socket.add_receiver(state.socket, receiver)
  end

  # Called by the broadcaster when it has finished sending in-flight packets.
  defp receiver_ready(receiver, state) do
    event!(state, :receiver_added, Receiver.id!(receiver))
    %S{ state | receivers: Set.put(state.receivers, receiver) }
  end

  defp event!(state, name, params) do
    Otis.State.Events.notify({name, state.id, params})
  end

  defp stream_finished!(state) do
    state |> stream_has_finished |> set_state(:stop)
  end

  defp stream_has_finished(%S{broadcaster: nil} = state) do
    state
  end
  defp stream_has_finished(state) do
    Otis.Broadcaster.Controller.done(state.ctrl)
    %S{state | broadcaster: nil}
  end

  defp toggle_state(%S{state: :play} = state) do
    set_state(state, :stop)
  end

  defp toggle_state(%S{state: :stop} = state) do
    set_state(state, :play)
  end

  defp set_state(zone, state) do
    %S{ zone | state: state } |> change_state
  end

  defp change_state(%S{state: :play, ctrl: nil} = state) do
    # TODO: share a ctrl between all zones
    ctrl = Otis.Zone.Controller.new(Otis.stream_interval_us)
    %S{ state | ctrl: ctrl } |> change_state
  end
  defp change_state(%S{state: :play, broadcaster: nil, ctrl: ctrl} = state) do
    {:ok, broadcaster} = start_broadcaster(state)
    ctrl = Otis.Broadcaster.Controller.start(ctrl, broadcaster, broadcaster_latency(state), @buffer_size)
    %S{ state | broadcaster: broadcaster, ctrl: ctrl }
  end
  defp change_state(%S{state: :play} = state) do
    state
  end
  defp change_state(%S{state: :stop, broadcaster: nil} = state) do
    Logger.debug("Zone stopped")
    zone_is_stopped(state)
  end
  defp change_state(%S{state: :stop, broadcaster: broadcaster} = state) do
    ctrl = Otis.Broadcaster.Controller.stop(state.ctrl, broadcaster)
    change_state(%S{ state | broadcaster: nil, ctrl: ctrl })
  end
  defp change_state(%S{state: :skip, broadcaster: nil} = state) do
    state
  end
  defp change_state(%S{id: _id, state: :skip, broadcaster: broadcaster} = state) do
    ctrl = Otis.Broadcaster.Controller.skip(state.ctrl, broadcaster)
    change_state(%S{ state | broadcaster: nil, ctrl: ctrl })
  end

  defp broadcaster_latency(state) do
    receiver_latency(state) + @buffer_latency
  end

  def receiver_latency(%S{receivers: receivers} = state) do
    receivers |> MapSet.to_list |> receiver_latency(state)
  end
  def receiver_latency([], state) do
    Logger.warn "No receivers attached to zone #{ state.id }"
    0
  end
  def receiver_latency(receivers, _state) do
    receivers |> Enum.map(&Receiver.latency!/1) |> Enum.max
  end

  defp zone_is_stopped(state) do
    Otis.Stream.reset(state.audio_stream)
    %S{ state | broadcaster: nil}
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