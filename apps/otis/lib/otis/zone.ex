defmodule Otis.Zone do
  require Logger

  @first_timestamp nil

  defstruct name:              "A Zone",
            id:                nil,
            source_stream:     nil,
            receivers:         HashSet.new,
            state:             :stop,
            broadcaster:       nil,
            audio_stream:      nil,
            timestamp:         @first_timestamp,
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

  @doc "Called by the broadcaster in order to keep our state in sync"
  def stream_finished(zone) do
    GenServer.cast(zone, :stream_finished)
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

  def handle_cast(:stream_finished, %Zone{} = zone) do
    zone = stream_finished!(zone)
    {:noreply, zone}
  end

  def receiver_latency(%Zone{receivers: recs}) do
    Enum.map(Set.to_list(recs), fn(rec) ->
      {:ok, latency} = Otis.Receiver.latency(rec)
      latency
    end) |> Enum.max
  end

  defp stream_finished!(%Zone{broadcaster: broadcaster} = zone) do
    Otis.Broadcaster.stream_finished(broadcaster)
    set_state(%Zone{zone | broadcaster: nil}, :stop)
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
    {:ok, pid } = start_broadcaster(zone)
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
    Otis.Broadcaster.stop_broadcaster(broadcaster)
    change_state(%Zone{ zone | broadcaster: nil })
  end

  defp zone_is_stopped(zone) do
    %Zone{ zone | timestamp: @first_timestamp, broadcaster: nil}
  end

  defp start_broadcaster(%Zone{audio_stream: audio_stream, socket: socket} = zone) do
    opts = [
      zone: self,
      audio_stream: audio_stream,
      socket: socket,
      latency: receiver_latency(zone),
      stream_interval: Otis.stream_interval_us
    ]
    Otis.Broadcaster.start_broadcaster(opts)
  end
end
