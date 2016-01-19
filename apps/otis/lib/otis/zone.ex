defmodule Otis.Zone do
  use     GenServer
  require Logger

  defstruct name:              "A Zone",
            id:                nil,
            source_list:       nil,
            receivers:         HashSet.new,
            state:             :stop,
            broadcaster:       nil,
            clock:             nil,
            audio_stream:      nil,
            broadcast_address: nil,
            socket:            nil,
            event_stream:      nil


  alias Otis.Zone, as: Zone

  # music starts playing after this many microseconds
  @buffer_latency     50_000
  @buffer_size        25

  def start_link(id, name) do
    start_link(id, name, Otis.SourceList.empty)
  end

  def start_link(id, name, {:ok, source_list}) do
    start_link(id, name, source_list)
  end

  def start_link(id, name, source_list) when is_binary(id) do
    start_link(String.to_atom(id), name, source_list)
  end

  def start_link(id, name, source_list) do
    GenServer.start_link(__MODULE__, %Zone{ id: id, name: name, source_list: source_list, broadcaster: nil }, name: id)
  end

  def init(%Zone{ source_list: source_list } = zone) do
    Logger.info "#{__MODULE__} starting... #{ inspect zone }"
    {:ok, port} = Otis.PortSequence.next
    {:ok, event_stream} = GenEvent.start_link([])
    {:ok, socket} = Otis.Zone.Socket.start_link(port)
    {:ok, audio_stream } = Otis.AudioStream.start_link(source_list, Otis.stream_bytes_per_step)
    {:ok, stream} = Otis.Zone.BufferedStream.seconds(audio_stream, 1)
    {:ok, %Zone{ zone |
        audio_stream: stream,
        socket: socket,
        broadcast_address: {port},
        event_stream: event_stream }
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

  def name(zone) do
    GenServer.call(zone, :name)
  end

  def receivers(zone) do
    GenServer.call(zone, :receivers)
  end

  def add_receiver(zone, receiver) do
    GenServer.call(zone, {:add_receiver, receiver})
  end

  def remove_receiver(zone, receiver) do
    GenServer.call(zone, {:remove_receiver, receiver})
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

  def broadcast_address(zone) do
    GenServer.call(zone, :get_broadcast_address)
  end

  @doc "Called by the broadcaster in order to keep our state in sync"
  def stream_finished(zone) do
    GenServer.cast(zone, :stream_finished)
  end

  @doc "Skip to the source with the given id"
  def skip(zone, count) do
    GenServer.cast(zone, {:skip, count})
  end

  def add_event_handler(zone, module, args) do
    GenServer.call(zone, {:add_event_handler, module, args})
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

  def handle_call(:id, _from, %Zone{id: id} = zone) do
    {:reply, {:ok, id}, zone}
  end

  def handle_call(:name, _from, %Zone{name: name} = zone) do
    {:reply, {:ok, name}, zone}
  end

  def handle_call(:receivers, _from, %Zone{receivers: receivers} = zone) do
    {:reply, {:ok, Set.to_list(receivers)}, zone}
  end

  def handle_call({:add_receiver, receiver}, _from, %Zone{ id: id} = zone) do
    Logger.info "Adding receiver to zone #{id}"
    zone = receiver_joined(receiver, zone)
    {:reply, :ok, zone}
  end

  def handle_call({:remove_receiver, receiver}, _from, %Zone{ receivers: receivers} = zone) do
    Logger.debug "Zone removing receiver..."
    {:reply, :ok, %Zone{ zone | receivers: Set.delete(receivers, receiver) }}
  end

  def handle_call(:play_pause, _from, zone) do
    zone = zone |> toggle_state
    {:reply, {:ok, zone.state}, zone}
  end

  def handle_call(:get_state, _from, %Zone{state: state} = zone) do
    {:reply, {:ok, state}, zone}
  end

  def handle_call(:get_audio_stream, _from, %Zone{audio_stream: audio_stream} = zone) do
    {:reply, {:ok, audio_stream}, zone}
  end

  def handle_call(:get_source_list, _from, %Zone{source_list: source_list} = zone) do
    {:reply, {:ok, source_list}, zone}
  end

  def handle_call(:get_broadcast_address, _from, %Zone{broadcast_address: broadcast_address} = zone) do
    {:reply, {:ok, broadcast_address}, zone}
  end

  def handle_call({:add_event_handler, module, args}, _from, zone) do
    :ok = GenEvent.add_handler(zone.event_stream, module, args)
    {:reply, {:ok, zone.event_stream}, zone}
  end

  def handle_cast(:stream_finished, %Zone{} = zone) do
    zone = stream_finished!(zone)
    {:noreply, zone}
  end

  # TODO: handle the case where we skip past the end of the source list...
  def handle_cast({:skip, count}, zone) do
    zone = zone |> set_state(:skip) |> flush |> skip_to(count)
    {:noreply, set_state(zone, :play)}
  end

  defp flush(zone) do
    Otis.Stream.flush(zone.audio_stream)
    zone
  end

  defp skip_to(zone, 1) do
    zone
  end
  defp skip_to(zone, count) do
    {:ok, _} = Otis.SourceList.skip(zone.source_list, count - 1)
    zone
  end

  defp receiver_joined(receiver, %Zone{state: :play, broadcaster: broadcaster} = zone) do
    Otis.Zone.Broadcaster.buffer_receiver(broadcaster)
    add_receiver_to_zone(receiver, zone)
  end

  defp receiver_joined(receiver, %Zone{state: :stop} = zone) do
    add_receiver_to_zone(receiver, zone)
  end

  defp add_receiver_to_zone(receiver, %Zone{receivers: receivers} = zone) do
    Otis.Receiver.join_zone(receiver, self, zone.broadcast_address)
    event!(:receiver_added, {Otis.Receiver.id!(receiver)}, zone)
    %Zone{ zone | receivers: Set.put(receivers, receiver) }
  end

  defp event!(name, params, zone) do
    GenEvent.notify(zone.event_stream, {name, zone.id, params})
  end

  def receiver_latency(%Zone{receivers: %HashSet{} = recs}) do
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

  defp stream_has_finished(%Zone{broadcaster: nil} = zone) do
    zone
  end
  defp stream_has_finished(zone) do
    Otis.Broadcaster.stream_finished(zone.broadcaster)
    %Zone{zone | broadcaster: nil}
  end

  defp toggle_state(%Zone{state: :play} = zone) do
    set_state(zone, :stop)
  end

  defp toggle_state(%Zone{state: :stop} = zone) do
    set_state(zone, :play)
  end

  defp set_state(zone, state) do
    %Zone{ zone | state: state } |> change_state
  end

  defp change_state(%Zone{state: :play, clock: nil} = zone) do
    # TODO: share a clock between all zones
    clock = Otis.Zone.Clock.new(Otis.stream_interval_us)
    %Zone{ zone | clock: clock } |> change_state
  end
  defp change_state(%Zone{state: :play, broadcaster: nil, clock: clock} = zone) do
    {:ok, pid } = start_broadcaster(zone)
    clock = Otis.Broadcaster.Clock.start(clock, pid, broadcaster_latency(zone), @buffer_size)
    %Zone{ zone | broadcaster: pid, clock: clock }
  end
  defp change_state(%Zone{state: :play} = zone) do
    zone
  end
  defp change_state(%Zone{state: :stop, broadcaster: nil} = zone) do
    Logger.debug("Zone stopped")
    zone_is_stopped(zone)
  end
  defp change_state(%Zone{id: _id, state: :stop, broadcaster: broadcaster} = zone) do
    Otis.Broadcaster.stop_broadcaster(broadcaster)
    change_state(%Zone{ zone | broadcaster: nil })
  end
  defp change_state(%Zone{state: :skip, broadcaster: nil} = zone) do
    zone
  end
  defp change_state(%Zone{id: _id, state: :skip, broadcaster: broadcaster} = zone) do
    Otis.Broadcaster.skip_broadcaster(broadcaster)
    change_state(%Zone{ zone | broadcaster: nil })
  end

  defp broadcaster_latency(zone) do
    receiver_latency(zone) + @buffer_latency
  end

  defp zone_is_stopped(zone) do
    Otis.Stream.reset(zone.audio_stream)
    %Zone{ zone | broadcaster: nil}
  end

  defp start_broadcaster(%Zone{audio_stream: audio_stream, socket: socket, clock: clock} = zone) do
    opts = %{
      zone: self,
      audio_stream: audio_stream,
      emitter: Otis.Zone.Emitter.new(socket),
      stream_interval: Otis.stream_interval_us
    }
    Otis.Broadcaster.start_broadcaster(opts)
  end
end
