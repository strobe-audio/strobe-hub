defmodule Otis.Channel do
  use     GenServer
  require Logger
  alias   Otis.Receiver, as: Receiver

  defmodule S do
    @moduledoc "The state struct for Channel processes"
    defstruct [
      id:                nil,
      playlist:       nil,
      # receivers:         MapSet.new,
      state:             :pause,
      broadcaster:       nil,
      # ctrl:              nil,
      # audio_stream:      nil,
      # socket:            nil,
      volume:            1.0,
    ]
  end

  defstruct [:id, :pid]

  # music starts playing after this many microseconds
  @buffer_latency     50_000
  @buffer_size        25

  def id!(channel) do
    {:ok, id} = id(channel)
    id
  end

  def id(%__MODULE__{id: id}) do
    {:ok, id}
  end
  def id(channel) do
    GenServer.call(channel, :id)
  end

  def socket(%__MODULE__{pid: pid} = _channel) do
    socket(pid)
  end
  def socket(channel) do
    GenServer.call(channel, :socket)
  end

  def state(channel) do
    GenServer.call(channel, :get_state)
  end

  def play_pause(channel) do
    GenServer.call(channel, :play_pause)
  end

  def playlist(channel) do
    GenServer.call(channel, :get_playlist)
  end

  def volume!(channel) do
    {:ok, volume} = volume(channel)
    volume
  end

  def volume(%__MODULE__{pid: pid}) do
    volume(pid)
  end
  def volume(channel) do
    GenServer.call(channel, :volume)
  end

  def volume(%__MODULE__{pid: pid}, volume) do
    volume(pid, volume)
  end
  def volume(channel, volume) do
    GenServer.call(channel, {:volume, volume})
  end

  def playing?(%__MODULE__{pid: pid}) do
    playing?(pid)
  end
  def playing?(channel) do
    GenServer.call(channel, :playing)
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
  def clear(channel) do
    GenServer.cast(channel, :clear)
  end

  def append(%__MODULE__{pid: pid}, sources) do
    append(pid, sources)
  end
  def append(channel, sources) do
    GenServer.call(channel, {:append_sources, sources})
  end

  def start_link(channel, config, name) do
    GenServer.start_link(__MODULE__, [channel, config], name: name)
  end

  alias Otis.Pipeline.Playlist
  alias Otis.Pipeline.Hub
  alias Otis.Pipeline.Clock
  alias Otis.Pipeline.Broadcaster

  def init([channel, config]) do
    Logger.info "#{__MODULE__} starting... #{ channel.id }"
    {:ok, playlist} = Playlist.start_link(channel.id)
    {:ok, hub} = Hub.start_link(playlist, config)
    {:ok, clock} = Otis.Pipeline.Config.start_clock(config)
    {:ok, broadcaster} = Broadcaster.start_link(channel.id, self(), hub, clock, config)
    {:ok, %S{
        id: channel.id,
        playlist: playlist,
        broadcaster: broadcaster,
        volume: Map.get(channel, :volume, 1.0)
      }
    }
  end


  # @doc "Called by the broadcaster in order to keep our state in sync"
  # def stream_finished(channel) do
  #   GenServer.cast(channel, :stream_finished)
  # end


  # def receiver_buffered(channel, receiver) do
  #   GenServer.cast(channel, {:receiver_buffered, receiver})
  # end
  #
  # def sources(%__MODULE__{pid: pid}) do
  #   sources(pid)
  # end
  # def sources(channel) do
  #   GenServer.call(channel, :sources)
  # end

  # def duration(%__MODULE__{pid: pid}) do
  #   duration(pid)
  # end
  # def duration(channel) do
  #   GenServer.call(channel, :duration)
  # end

  def play(%__MODULE__{pid: pid}, playing) do
    play(pid, playing)
  end
  def play(channel, playing) do
    GenServer.call(channel, {:play, playing})
  end

  # Things we can do to channels:
  # - change source stream
  # - on the attached source stream:
  #   - add/remove sources
  #   - re-order sources
  #   - change position in source stream (skip track)
  # - get playing state
  # - start / pause
  # - change volume (?)

  # add sources play next
  # add sources play now
  # append sources
  # skip track
  # rewind track

  def handle_call(:id, _from, %S{id: id} = state) do
    {:reply, {:ok, id}, state}
  end

  # def handle_call(:receivers, _from, %S{receivers: receivers} = state) do
  #   {:reply, {:ok, Set.to_list(receivers)}, state}
  # end

  # def handle_call(:socket, _from, %S{socket: socket} = state) do
  #   {:reply, {:ok, socket}, state}
  # end

  # def handle_call({:add_receiver, receiver}, _from, %S{id: id} = state) do
  #   Logger.info "Adding receiver to channel #{id} #{inspect receiver}"
  #   state = add_receiver_to_channel(receiver, state)
  #   {:reply, :ok, state}
  # end

  def handle_call({:play, play}, _from, state) do
    state = state |> set_state(:play)
    # state = state |> toggle_state
    {:reply, {:ok, state.state}, state}
  end
  def handle_call(:play_pause, _from, state) do
    state = state |> toggle_state
    {:reply, {:ok, state.state}, state}
  end

  def handle_call(:get_state, _from, %S{state: status} = state) do
    {:reply, {:ok, status}, state}
  end

  # def handle_call(:get_audio_stream, _from, %S{audio_stream: audio_stream} = state) do
  #   {:reply, {:ok, audio_stream}, state}
  # end

  def handle_call(:get_playlist, _from, %S{playlist: playlist} = state) do
    {:reply, {:ok, playlist}, state}
  end

  def handle_call(:volume, _from, %S{volume: volume} = state) do
    {:reply, {:ok, volume}, state}
  end
  def handle_call({:volume, volume}, _from, state) do
    volume = Otis.sanitize_volume(volume)
    Otis.Receivers.Sets.volume_multiplier(state.id, volume)
    event!(state, :channel_volume_change, volume)
    {:reply, {:ok, volume}, %S{state | volume: volume}}
  end

  def handle_call({:append_sources, sources}, _from, state) do
    Playlist.append(state.playlist, sources)
    {:reply, :ok, state}
  end

  # def handle_call(:sources, _from, state) do
  #   sources = Playlist.list(state.playlist)
  #   {:reply, sources, state}
  # end

  # def handle_call(:duration, _from, state) do
  #   duration = Otis.SourceList.duration(state.source_list)
  #   {:reply, duration, state}
  # end

  def handle_call(:playing, _from, %S{state: status} = state) do
    {:reply, status == :play, state}
  end

  # def handle_call({:play, true}, _from, %S{state: :play} = state) do
  #   {:reply, {:ok, state.state}, state}
  # end
  # def handle_call({:play, false}, _from, %S{state: :stop} = state) do
  #   {:reply, {:ok, state.state}, state}
  # end
  # def handle_call({:play, _play}, _from, state) do
  #   state = state |> toggle_state
  #   {:reply, {:ok, state.state}, state}
  # end

  # def handle_cast(:stream_finished, state) do
  #   {:noreply, stream_finished!(state)}
  # end

  # TODO: handle the case where we skip past the end of the source list...
  def handle_cast({:skip, id}, state) do
    # state = state |> set_state(:skip) |> flush |> skip_to(id) |> set_state(:play)
    # Otis.Stream.skip(state.audio_stream, id)
    {:noreply, state}
  end

  def handle_cast(:clear, state) do
    # state = state |> set_state(:stop) |> flush |> clear_playlist()
    {:noreply, state}
  end

  # Called by the broadcaster when it has finished sending in-flight packets.
  def handle_cast({:receiver_buffered, receiver}, state) do
    # state = receiver_ready(receiver, state)
    {:noreply, state}
  end

  # Don't need to do anything here as the start has been initiated by us
  def handle_info(:broadcaster_start, state) do
    IO.inspect [:channel, :broadcaster_start]
    {:noreply, state}
  end
  # Stop events come when the audio has actually finished as well as when we
  # send a stop event
  def handle_info(:broadcaster_stop, state) do
    IO.inspect [:channel, :broadcaster_stop]
    state = state |> set_state(:pause)
    {:noreply, state}
  end
  # def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
  #   state = case Receiver.matching_pid(state.receivers, pid) do
  #     nil ->
  #       broadcaster_shutdown(pid, state)
  #     receiver ->
  #       receiver_shutdown(receiver, state)
  #   end
  #   {:noreply, state}
  # end

  # defp broadcaster_shutdown(_pid, %S{state: :play} = state) do
  #   ctrl = Otis.Broadcaster.Controller.start(state.ctrl, state.broadcaster, broadcaster_latency(state), @buffer_size)
  #   %S{state | ctrl: ctrl}
  # end
  # defp broadcaster_shutdown(_pid, state) do
  #   state
  # end

  # def receiver_shutdown(nil, state) do
  #   state
  # end
  # def receiver_shutdown(receiver, state) do
  #   event!(state, :receiver_removed, Receiver.id!(receiver))
  #   %S{ state | receivers: MapSet.delete(state.receivers, receiver) }
  # end
  #
  # defp flush(state) do
  #   Otis.Stream.flush(state.audio_stream)
  #   state
  # end

  defp skip_to(state, id) do
    :ok = Playlist.skip(state.playlist, id)
    state
  end

  defp clear_playlist(state) do
    :ok = Playlist.clear(state.playlist)
    state
  end

  # defp add_receiver_to_channel(receiver, %S{state: :play, broadcaster: broadcaster} = state) do
  #   adopt_receiver(receiver, state)
  #   Otis.Channel.Broadcaster.buffer_receiver(broadcaster, self(), receiver)
  #   state
  # end
  #
  # defp add_receiver_to_channel(receiver, %S{state: :stop} = state) do
  #   adopt_receiver(receiver, state)
  #   receiver_ready(receiver, state)
  # end
  #
  # defp adopt_receiver(receiver, state) do
  #   Receiver.monitor(receiver)
  #   Receiver.volume_multiplier(receiver, state.volume)
  #   # I have to add the receiver to the socket here because the quick-buffering
  #   # system needs to send the packets to the receiver immediately.
  #   Otis.Channel.Socket.add_receiver(state.socket, receiver)
  # end

  # Called by the broadcaster when it has finished sending in-flight packets.
  # defp receiver_ready(receiver, state) do
  #   event!(state, :receiver_added, Receiver.id!(receiver))
  #   %S{ state | receivers: Set.put(state.receivers, receiver) }
  # end

  defp event!(state, name, params) do
    Otis.State.Events.notify({name, [state.id, params]})
  end

  # defp stream_finished!(state) do
  #   state |> stream_has_finished |> set_state(:stop)
  # end

  # defp stream_has_finished(%S{broadcaster: nil} = state) do
  #   state
  # end
  # defp stream_has_finished(state) do
  #   Otis.Broadcaster.Controller.done(state.ctrl)
  #   %S{state | broadcaster: nil}
  # end

  defp toggle_state(%S{state: :play} = state) do
    IO.inspect [:toggle, :play, :pause]
    set_state(state, :pause)
  end

  defp toggle_state(%S{state: :pause} = state) do
    IO.inspect [:toggle, :pause, :play]
    set_state(state, :play)
  end

  defp set_state(%S{state: status} = state, status) do
    state
  end
  defp set_state(channel, state) do
    %S{ channel | state: state } |> change_state
  end

  defp change_state(%S{state: :play} = state) do
    Broadcaster.start(state.broadcaster)
    event!(state, :channel_play_pause, :play)
    state
  end
  defp change_state(%S{state: :pause} = state) do
    Broadcaster.pause(state.broadcaster)
    event!(state, :channel_play_pause, :pause)
    state
  end
  # defp change_state(%S{state: :play} = state) do
  #   # TODO: share a ctrl between all channels
  #   ctrl = Otis.Channel.Controller.new(Otis.stream_interval_us)
  #   %S{ state | ctrl: ctrl } |> change_state()
  # end
  # defp change_state(%S{state: :play, broadcaster: nil, ctrl: ctrl} = state) do
  #   broadcaster = start_broadcaster(state)
  #   ctrl = Otis.Broadcaster.Controller.start(ctrl, broadcaster, broadcaster_latency(state), @buffer_size)
  #   Otis.Stream.resume(state.audio_stream)
  #   event!(state, :channel_play_pause, :play)
  #   %S{ state | broadcaster: broadcaster, ctrl: ctrl }
  # end
  # defp change_state(%S{state: :play} = state) do
  #   state
  # end
  # defp change_state(%S{state: :stop, broadcaster: nil} = state) do
  #   channel_is_stopped(state)
  # end
  # defp change_state(%S{state: :stop, broadcaster: broadcaster} = state) do
  #   ctrl = Otis.Broadcaster.Controller.stop(state.ctrl, broadcaster)
  #   # TODO: change :stop state to :pause
  #   event!(state, :channel_play_pause, :pause)
  #   change_state(%S{ state | broadcaster: nil, ctrl: ctrl })
  # end
  # defp change_state(%S{state: :skip, broadcaster: nil} = state) do
  #   state
  # end
  # defp change_state(%S{id: _id, state: :skip, broadcaster: broadcaster} = state) do
  #   ctrl = Otis.Broadcaster.Controller.skip(state.ctrl, broadcaster)
  #   change_state(%S{ state | broadcaster: nil, ctrl: ctrl })
  # end

  # defp broadcaster_latency(state) do
  #   receiver_latency(state) + @buffer_latency
  # end

  # def receiver_latency(%S{receivers: receivers} = state) do
  #   receivers |> MapSet.to_list |> receiver_latency(state)
  # end
  # def receiver_latency([], state) do
  #   Logger.warn "No receivers attached to channel #{ state.id }"
  #   0
  # end
  # def receiver_latency(receivers, _state) do
  #   receivers |> Enum.map(&Receiver.latency!/1) |> Enum.max
  # end

  # defp channel_is_stopped(state) do
  #   Otis.Stream.reset(state.audio_stream)
  #   %S{ state | broadcaster: nil}
  # end

  # defp start_broadcaster(%S{id: id, audio_stream: audio_stream, socket: socket}) do
  #   opts = %{
  #     id: id,
  #     channel: self(),
  #     audio_stream: audio_stream,
  #     emitter: Otis.Channel.Emitter.new(socket),
  #     stream_interval: Otis.stream_interval_us
  #   }
  #   {:ok, pid} = Otis.Broadcaster.start_broadcaster(opts)
  #   Process.monitor(GenServer.whereis(pid))
  #   pid
  # end
end