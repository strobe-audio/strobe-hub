defmodule Otis.Zone do
  require Logger

  defstruct name:          "A Zone",
            id:            nil,
            source_stream: nil,
            receivers:     HashSet.new,
            state:         :stop,
            broadcaster:   nil,
            audio_stream:  nil,
            timestamp:     0

  use GenServer

  alias Otis.Zone, as: Zone

  def start_link(id, name) do
    start_link(id, name, Otis.SourceStream.Array.empty)
  end

  def start_link(id, name, {:ok, source_stream }) do
    start_link(id, name, source_stream)
  end

  def start_link(id, name, source_stream) do
    GenServer.start_link(__MODULE__, %Zone{ id: id, name: name, source_stream: source_stream, broadcaster: nil })
  end

  def init(%Zone{ source_stream: source_stream } = zone) do
    {:ok, audio_stream } = Otis.AudioStream.start_link(source_stream, Otis.stream_bytes_per_step)
    {:ok, %Zone{ zone | audio_stream: audio_stream }}
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

  def handle_call(:id, _from, %Zone{id: id} = zone) do
    {:reply, {:ok, id}, zone}
  end

  def handle_call(:name, _from, %Zone{name: name} = zone) do
    {:reply, {:ok, name}, zone}
  end

  def handle_call(:receivers, _from, %Zone{receivers: receivers} = zone) do
    {:reply, {:ok, Set.to_list(receivers)}, zone}
  end

  def handle_call({:add_receiver, receiver}, _from, %Zone{ receivers: receivers} = zone) do
    {:reply, :ok, %Zone{ zone | receivers: Set.put(receivers, receiver) }}
  end

  def handle_call({:remove_receiver, receiver}, _from, %Zone{ receivers: receivers} = zone) do
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

  def handle_cast(:broadcast, %Zone{ state: :play, receivers: []} = zone) do
    Logger.info "Zone has no configured receivers"
    {:noreply, set_state(zone, :stop)}
  end

  def handle_cast(:broadcast, %Zone{ state: :play, audio_stream: audio_stream, receivers: receivers} = zone) do
    frame = Otis.AudioStream.frame(audio_stream)
    zone = start_broadcast_frame(frame, Set.to_list(receivers), zone)
    {:noreply, zone}
  end

  def start_broadcast_frame({:ok, data} = frame, recs, %Zone{timestamp: timestamp} = zone) do
    timestamp = next_timestamp(timestamp, recs)
    broadcast_frame({:ok, data, timestamp}, recs, %Zone{zone | timestamp: timestamp})
  end

  def start_broadcast_frame(:stopped,  _recs, zone) do
    set_state(zone, :stop)
  end

  def next_timestamp(timestamp, recs) do
    offset = Enum.map(recs, fn(rec) ->
      {:ok, latency} = Otis.Receiver.latency(rec)
      latency
    end) |> Enum.max
    next_timestamp_with_offset(timestamp, offset)
  end

  def next_timestamp_with_offset(0, offset) do
    Otis.microseconds + (2 * Otis.stream_interval_us) + offset
  end

  def next_timestamp_with_offset(timestamp, _offset) do
    timestamp + Otis.stream_interval_us
  end

  def broadcast_frame({:ok, data, timestamp}, [r | t], zone) do
    Otis.Receiver.receive_frame(r, data, timestamp)
    broadcast_frame({:ok, data, timestamp}, t, zone)
  end

  def broadcast_frame({:ok, data, timestamp}, [], zone) do
    zone
  end

  def handle_cast(:broadcast, %Zone{ state: :stop} = zone) do
    {:noreply, zone}
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

  defp change_state(%Zone{id: id, state: :stop, broadcaster: broadcaster} = zone) do
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
