defmodule Otis.Channel do
  use     GenServer
  require Logger
  alias   Otis.Receiver, as: Receiver

  defmodule S do
    @moduledoc "The state struct for Channel processes"
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
    GenServer.start_link(__MODULE__, {id, config, source_list}, name: String.to_atom("channel-#{id}"))
  end

  def init({id, config, source_list}) do
    Logger.info "#{__MODULE__} starting... #{ id }"
    {:ok, socket} = Otis.Channel.Socket.start_link(id)
    stream_config = Otis.Stream.Config.seconds(1)
    {:ok, stream} = Otis.Stream.Supervisor.start_buffered_stream(id, stream_config, source_list)
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
  def id(channel) do
    GenServer.call(channel, :id)
  end

  def receivers(%__MODULE__{pid: pid} = _channel) do
    receivers(pid)
  end
  def receivers(channel) do
    GenServer.call(channel, :receivers)
  end

  def socket(%__MODULE__{pid: pid} = _channel) do
    socket(pid)
  end
  def socket(channel) do
    GenServer.call(channel, :socket)
  end

  def add_receiver(%__MODULE__{pid: pid} = _channel, receiver) do
    add_receiver(pid, receiver)
  end
  def add_receiver(channel, receiver) when is_pid(channel) do
    GenServer.call(channel, {:add_receiver, receiver})
  end

  def state(channel) do
    GenServer.call(channel, :get_state)
  end

  def play_pause(channel) do
    GenServer.call(channel, :play_pause)
  end

  def source_list(channel) do
    GenServer.call(channel, :get_source_list)
  end

  def audio_stream(channel) do
    GenServer.call(channel, :get_audio_stream)
  end

  def volume!(channel) do
    {:ok, volume} = volume(channel)
    volume
  end

  def volume(%__MODULE__{pid: pid}) do
    volume(pid)
  end
  def volume(channel) when is_pid(channel) do
    GenServer.call(channel, :volume)
  end
  def volume(%__MODULE__{pid: pid}, volume) do
    volume(pid, volume)
  end
  def volume(channel, volume) when is_pid(channel) do
    GenServer.call(channel, {:volume, volume})
  end

  def playing?(%__MODULE__{pid: pid}) do
    playing?(pid)
  end
  def playing?(channel) when is_pid(channel) do
    GenServer.call(channel, :playing)
  end

  @doc "Called by the broadcaster in order to keep our state in sync"
  def stream_finished(channel) do
    GenServer.cast(channel, :stream_finished)
  end

  @doc "Skip to the source with the given id"
  def skip(%__MODULE__{pid: pid}, source_id) do
    skip(pid, source_id)
  end
  def skip(channel, source_id) do
    GenServer.cast(channel, {:skip, source_id})
  end

  def clear(%__MODULE__{pid: pid}) do
    clear(pid)
  end
  def clear(channel) when is_pid(channel) do
    GenServer.cast(channel, :clear)
  end

  def receiver_buffered(channel, receiver) do
    GenServer.cast(channel, {:receiver_buffered, receiver})
  end

  def append(%__MODULE__{pid: pid}, sources) do
    append(pid, sources)
  end
  def append(channel, sources) do
    GenServer.call(channel, {:append_sources, sources})
  end

  def sources(%__MODULE__{pid: pid}) do
    sources(pid)
  end
  def sources(channel) do
    GenServer.call(channel, :sources)
  end

  def duration(%__MODULE__{pid: pid}) do
    duration(pid)
  end
  def duration(channel) do
    GenServer.call(channel, :duration)
  end

  def play(%__MODULE__{pid: pid}, playing) do
    play(pid, playing)
  end
  def play(channel, playing) do
    GenServer.call(channel, {:play, playing})
  end

  # Things we can do to channels:
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
    Logger.info "Adding receiver to channel #{id} #{inspect receiver}"
    state = add_receiver_to_channel(receiver, state)
    {:reply, :ok, state}
  end

  def handle_call(:play_pause, _from, state) do
    state = state |> toggle_state
    {:reply, {:ok, state.state}, state}
  end

  def handle_call(:get_state, _from, %S{state: status} = state) do
    {:reply, {:ok, status}, state}
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
    Otis.State.Events.notify({:channel_volume_change, [state.id, volume]})
    {:reply, {:ok, volume}, %S{state | volume: volume}}
  end

  def handle_call({:append_sources, sources}, _from, state) do
    Otis.SourceList.append(state.source_list, sources)
    {:reply, :ok, state}
  end

  def handle_call(:sources, _from, state) do
    sources = Otis.SourceList.list(state.source_list)
    {:reply, sources, state}
  end

  def handle_call(:duration, _from, state) do
    duration = Otis.SourceList.duration(state.source_list)
    {:reply, duration, state}
  end

  def handle_call(:playing, _from, %S{state: status} = state) do
    {:reply, status == :play, state}
  end

  def handle_call({:play, true}, _from, %S{state: :play} = state) do
    {:reply, {:ok, state.state}, state}
  end
  def handle_call({:play, false}, _from, %S{state: :stop} = state) do
    {:reply, {:ok, state.state}, state}
  end
  def handle_call({:play, _play}, _from, state) do
    state = state |> toggle_state
    {:reply, {:ok, state.state}, state}
  end

  def handle_cast(:stream_finished, state) do
    {:noreply, stream_finished!(state)}
  end

  # TODO: handle the case where we skip past the end of the source list...
  def handle_cast({:skip, id}, state) do
    state = state |> set_state(:skip) |> flush |> skip_to(id) |> set_state(:play)
    Otis.Stream.skip(state.audio_stream, id)
    {:noreply, state}
  end

  def handle_cast(:clear, state) do
    state = state |> set_state(:stop) |> flush |> clear_playlist()
    {:noreply, state}
  end

  # Called by the broadcaster when it has finished sending in-flight packets.
  def handle_cast({:receiver_buffered, receiver}, state) do
    state = receiver_ready(receiver, state)
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
    event!(state, :receiver_removed, Receiver.id!(receiver))
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

  defp clear_playlist(state) do
    :ok = Otis.SourceList.clear(state.source_list)
    state
  end

  defp add_receiver_to_channel(receiver, %S{state: :play, broadcaster: broadcaster} = state) do
    adopt_receiver(receiver, state)
    Otis.Channel.Broadcaster.buffer_receiver(broadcaster, self, receiver)
    state
  end

  defp add_receiver_to_channel(receiver, %S{state: :stop} = state) do
    adopt_receiver(receiver, state)
    receiver_ready(receiver, state)
  end

  defp adopt_receiver(receiver, state) do
    Receiver.monitor(receiver)
    Receiver.volume_multiplier(receiver, state.volume)
    # I have to add the receiver to the socket here because the quick-buffering
    # system needs to send the packets to the receiver immediately.
    Otis.Channel.Socket.add_receiver(state.socket, receiver)
  end

  # Called by the broadcaster when it has finished sending in-flight packets.
  defp receiver_ready(receiver, state) do
    event!(state, :receiver_added, Receiver.id!(receiver))
    %S{ state | receivers: Set.put(state.receivers, receiver) }
  end

  defp event!(state, name, params) do
    Otis.State.Events.notify({name, [state.id, params]})
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

  defp set_state(%S{state: status} = state, status) do
    state
  end
  defp set_state(channel, state) do
    %S{ channel | state: state } |> change_state
  end

  defp change_state(%S{state: :play, ctrl: nil} = state) do
    # TODO: share a ctrl between all channels
    ctrl = Otis.Channel.Controller.new(Otis.stream_interval_us)
    %S{ state | ctrl: ctrl } |> change_state
  end
  defp change_state(%S{state: :play, broadcaster: nil, ctrl: ctrl} = state) do
    {:ok, broadcaster} = start_broadcaster(state)
    ctrl = Otis.Broadcaster.Controller.start(ctrl, broadcaster, broadcaster_latency(state), @buffer_size)
    Otis.Stream.resume(state.audio_stream)
    Otis.State.Events.notify({:channel_play_pause, state.id, :play})
    %S{ state | broadcaster: broadcaster, ctrl: ctrl }
  end
  defp change_state(%S{state: :play} = state) do
    state
  end
  defp change_state(%S{state: :stop, broadcaster: nil} = state) do
    channel_is_stopped(state)
  end
  defp change_state(%S{state: :stop, broadcaster: broadcaster} = state) do
    ctrl = Otis.Broadcaster.Controller.stop(state.ctrl, broadcaster)
    # TODO: change :stop state to :pause
    Otis.State.Events.notify({:channel_play_pause, state.id, :pause})
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
    Logger.warn "No receivers attached to channel #{ state.id }"
    0
  end
  def receiver_latency(receivers, _state) do
    receivers |> Enum.map(&Receiver.latency!/1) |> Enum.max
  end

  defp channel_is_stopped(state) do
    Otis.Stream.reset(state.audio_stream)
    %S{ state | broadcaster: nil}
  end

  defp start_broadcaster(%S{id: id, audio_stream: audio_stream, socket: socket}) do
    opts = %{
      id: id,
      channel: self,
      audio_stream: audio_stream,
      emitter: Otis.Channel.Emitter.new(socket),
      stream_interval: Otis.stream_interval_us
    }
    Otis.Broadcaster.start_broadcaster(opts)
  end
end