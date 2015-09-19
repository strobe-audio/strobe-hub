defmodule Otis.Zone do
  require Logger

  defstruct name:              "A Zone",
            id:                nil,
            source_stream:     nil,
            receivers:         HashSet.new,
            state:             :stop,
            broadcaster:       nil,
            audio_stream:      nil,
            timestamp:         0,
            last_broadcast:    0,
            broadcast_address: nil,
            socket:         nil

  use GenServer

  alias Otis.Zone, as: Zone

  def start_link(id, name) do
    start_link(id, name, Otis.SourceStream.Array.empty)
  end

  def start_link(id, name, {:ok, source_stream }) do
    start_link(id, name, source_stream)
  end

  def start_link(id, name, source_stream) when is_binary(id) do
    start_link(String.to_atom(id), name, source_stream)
  end

  def start_link(id, name, source_stream) do
    GenServer.start_link(__MODULE__, %Zone{ id: id, name: name, source_stream: source_stream, broadcaster: nil }, name: id)
  end

  def init(%Zone{ source_stream: source_stream } = zone) do
    {:ok, ip, port} = Otis.IPPool.next_address
    {:ok, socket} = Otis.Zone.Socket.start_link({ip, port})
    {:ok, audio_stream } = Otis.AudioStream.start_link(source_stream, Otis.stream_bytes_per_step)
    {:ok, %Zone{ zone | audio_stream: audio_stream, socket: socket, broadcast_address: {ip, port} }}
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

  def source_stream(zone) do
    GenServer.call(zone, :get_source_stream)
  end

  def audio_stream(zone) do
    GenServer.call(zone, :get_audio_stream)
  end

  def broadcast_address(zone) do
    GenServer.call(zone, :get_broadcast_address)
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

  def handle_call({:add_receiver, receiver}, _from, %Zone{ id: id, receivers: receivers} = zone) do
    Logger.info "Adding receiver to zone #{id}"
    Otis.Receiver.join_zone(receiver, self)
    {:reply, :ok, %Zone{ zone | receivers: Set.put(receivers, receiver) }}
  end

  def handle_call({:remove_receiver, receiver}, _from, %Zone{ receivers: receivers} = zone) do
    Logger.debug "Zone removing receiver..."
    {:reply, :ok, %Zone{ zone | receivers: Set.delete(receivers, receiver) }}
  end

  def handle_call(:play_pause, _from, zone) do
    zone = %Zone{state: state} = toggle_state(zone) |> change_state
    {:reply, {:ok, state}, zone}
  end

  def handle_call(:get_state, _from, %Zone{state: state} = zone) do
    {:reply, {:ok, state}, zone}
  end

  def handle_call(:get_audio_stream, _from, %Zone{audio_stream: audio_stream} = zone) do
    {:reply, {:ok, audio_stream}, zone}
  end

  def handle_call(:get_source_stream, _from, %Zone{source_stream: source_stream} = zone) do
    {:reply, {:ok, source_stream}, zone}
  end

  def handle_call(:get_broadcast_address, _from, %Zone{broadcast_address: broadcast_address} = zone) do
    {:reply, {:ok, broadcast_address}, zone}
  end

  def handle_cast(:broadcast, %Zone{ state: :play, receivers: []} = zone) do
    Logger.info "Zone has no configured receivers"
    {:noreply, set_state(zone, :stop)}
  end

  def handle_call(:broadcast, _from, %Zone{ state: :play, audio_stream: audio_stream, receivers: receivers, last_broadcast: last_broadcast} = zone) do
    frame = Otis.AudioStream.frame(audio_stream)
    zone = start_broadcast_frame(frame, Set.to_list(receivers), zone)
    # Logger.debug "Gap #{ms - last_broadcast} #{Otis.stream_interval_ms}"
    {:reply, :ok, zone}
  end

  def handle_cast(:broadcast, %Zone{ state: :stop} = zone) do
    {:noreply, zone}
  end

  def start_broadcast_frame({:ok, data} = _frame, recs, %Zone{timestamp: timestamp} = zone) do
    timestamp = next_timestamp(timestamp, recs)
    broadcast_frame({:ok, data, timestamp}, %Zone{zone | timestamp: timestamp})
  end

  def start_broadcast_frame(:stopped,  _recs, zone) do
    set_state(zone, :stop)
  end

  def next_timestamp(timestamp, recs) do
    next_timestamp_with_offset(timestamp, receiver_latency(recs))
  end

  def receiver_latency(recs) do
    Enum.map(recs, fn(rec) ->
      {:ok, latency} = Otis.Receiver.latency(rec)
      latency
    end) |> Enum.max
  end

  defp buffer_time(offset) do
    (8 * Otis.stream_interval_us) + offset
  end

  def next_timestamp_with_offset(0, offset) do
    Otis.microseconds + buffer_time(offset)
  end

  def next_timestamp_with_offset(timestamp, _offset) do
    timestamp + Otis.stream_interval_us
  end

  def broadcast_frame({:ok, data, timestamp}, %Zone{socket: socket} = zone) do
    Otis.Zone.Socket.send(socket, timestamp, data)
    %Zone{zone | last_broadcast: Otis.milliseconds}
  end

  def broadcast_frame(:stop, %Zone{socket: socket} = zone) do
    Otis.Zone.Socket.stop(socket)
    zone
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

  defp change_state(%Zone{state: :play, broadcaster: nil} = zone) do
    {:ok, pid } = start_broadcaster
    %Zone{ zone | broadcaster: pid }
  end

  defp change_state(%Zone{state: :play} = zone) do
    zone
  end

  defp change_state(%Zone{state: :stop, broadcaster: nil} = zone) do
    Logger.debug("Zone stopped")
    zone_is_stopped(zone)
  end

  defp change_state(%Zone{id: _id, state: :stop, broadcaster: broadcaster} = zone) do
    Otis.Broadcaster.stop(broadcaster)
    change_state(%Zone{ zone | broadcaster: nil })
  end

  defp zone_is_stopped(zone) do
    %Zone{ zone | timestamp: 0, broadcaster: nil}
  end

  defp start_broadcaster do
    Otis.Broadcaster.start_link(self, Otis.stream_interval_ms)
  end
end
