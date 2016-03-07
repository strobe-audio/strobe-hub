
defmodule Otis.Zone.Broadcaster do
  @moduledoc """
  This takes a zone and audio source and translates it into a set of
  timestamped packets. It then queues this to send to the clients.
  """

  use     GenServer
  require Logger

  # initial packets are sent out with this interval
  @fast_emit_interval 10_000


  defmodule S do
    @moduledoc "State for the broadcaster genserver"
    defstruct [
      id: nil,
      zone: nil,
      audio_stream: nil,
      emitter: nil,
      clock: nil,
      latency: 0.0,
      stream_interval: 0,
      start_time: 0,
      packet_number: 0,
      in_flight: [],
      source_id: nil,
      emit_time: 0,
      state: :play
    ]
  end

  # - We should flood fill the clients' buffers by sending far-future
  #   timestamped packets
  # - The emitter module that actually sends the data at a given timestamp has
  #   the time of transmission separated from the playback timestamp
  # - I want to save a list of 'in flight' packets that can be flood-sent to new
  #   receivers when they join
  # - The broadcaster gets a receiver latency from the zone when it starts, it
  #   should use that to calculate the broadcast latency (time between start &
  #   first packet play)
  # - Broadcaster is responsible for pulling the packets from the stream, not the zone
  # - Buffer is trimmed to only packets in the future (or future - broadcast latency)
  # - Broadcaster should record the time when it starts & base all timestamp info
  #   on that.
  # - Timestamp of packet = start time + broadcast latency + receiver latency + (packet no. * stream interval)
  # - Could keep buffered packets in 'abstract' {offset, data} rather than
  #   {timestamp, data} and calculate the actual timestamp when they are sent to
  #   the emitter (makes resending easy). offset = (packet no. * stream interval)

  def buffer_interval(stream_interval) do
    round(stream_interval / 4)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def buffer_receiver(broadcaster) do
    GenServer.cast(broadcaster, :buffer_receiver)
  end


  def init(opts) do
    Logger.info "Starting broadcaster #{inspect opts}"
    # Logger.disable(self)
    state = %S{
      id: opts.id,
      zone: opts.zone,
      audio_stream: opts.audio_stream,
      emitter: opts.emitter,
      stream_interval: opts.stream_interval
    }
    {:ok, state}
  end

  @doc "Pre-fills the buffer - can be used to minimise startup delays in certain circumstances"
  def handle_call(:prebuffer, _from, state) do
    Otis.AudioStream.buffer(state.audio_stream)
    {:reply, :ok, state}
  end

  def handle_call({:start, clock, latency, buffer_size}, _from, state) do
    {:reply, :ok, start(clock, latency, buffer_size, state)}
  end

  @doc "Called periodically by the assigned controller instance to prompt for new packets"
  def handle_call({:emit, interval}, _from, state) do
    state |> potentially_emit(interval) |> monitor_finish(:call)
  end

  def handle_cast({:emit, interval}, state) do
    state |> potentially_emit(interval) |> monitor_finish(:cast)
  end

  @doc """
  This stops the broadcaster quickly (sending a <<STOP>> to the receivers)
  but pushes back any unplayed packets to the source stream so that when
  we press play again, we start from where we left off.
  """
  def handle_cast({:stop, :stop}, state) do
    {:stop, {:shutdown, :stopped}, stop!(state)}
  end

  # The resend_packets system just resulted in the newly joined receiver
  # trying to play very stale packets and hence joining the zone with
  # very out-of-sync audio.
  def handle_cast(:buffer_receiver, state) do
    packets = state |> bufferable_packets
    resend_packets(packets, state)
    {:noreply, state}
  end

  @doc """
  This stops the broadcaster & drops any unsent packets
  Used during track skipping
  """
  def handle_cast({:stop, :skip}, state) do
    {:stop, {:shutdown, :stopped}, kill!(state)}
  end

  # The internal implementation of the start action called by the
  # controller. It's responsible for setting up the initial state
  # and sending out the initial flood of packets that will ensure
  # the receiver's have a good buffer of packets ready to play but
  # won't delay the actual start of the music playing.
  defp start(clock, latency, buffer_size, state) do
    Logger.info ">>>>>>>>>>>>> Fast send start......"
    {packets, packet_number} = next_packet(buffer_size, state)
    now = current_time(clock)
    state = %S{ state |
      clock: clock,
      start_time: now,
      emit_time: now,
      packet_number: packet_number,
      latency: latency
    }
    state = fast_send_packets(packets, state) |> monitor_in_flight
    Logger.info "<<<<<<<<<<<<< Fast send over ......"
    state
  end

  defp kill!(state) do
    Logger.info "Killing broadcaster..."
    kill(state)
  end

  defp kill(state) do
    Otis.Broadcaster.Emitter.stop(state.emitter)
    stop_inflight_packets(state)
  end

  # The 'stop' button has been pressed so pull back anything we were about to
  # send
  defp stop!(state) do
    Logger.info "Stopping broadcaster..."
    Otis.State.Events.notify({:zone_stop, state.id})
    kill(state)
    rebuffer_in_flight(state)
  end

  defp monitor_finish(%S{state: :stopped} = state, _callback) do
    {:stop, {:shutdown, :stopped}, state}
  end
  defp monitor_finish(state, :call) do
    {:reply, :ok, state}
  end
  defp monitor_finish(state, :cast) do
    {:noreply, state}
  end

  # The audio stream has finished, so tell the zone we're done so it can shut
  # us down properly
  defp finish(%S{in_flight: [], state: :stopped} = state) do
    state
  end
  defp finish(%S{in_flight: [], zone: zone, state: :play} = state) do
    Logger.debug "Stream finished"
    source_changed(nil, state.source_id, state)
    Otis.State.Events.notify({:zone_finished, state.id})
    Otis.Zone.stream_finished(zone)
    %S{ state | state: :stopped }
  end
  defp finish(state) do
    monitor_in_flight(state)
  end

  defp potentially_emit(state, interval) do
    time = current_time(state)
    next_check = time + interval
    diff = (next_check - state.emit_time)
    if (abs(diff) < interval) || (diff > 0) do
      state = send_next_packet(state)
    end
    state
  end

  defp resend_packets(packets, state) do
    resend_packets(packets, state, current_time(state) + 2_000, buffer_interval(state.stream_interval))
  end
  defp resend_packets([packet | packets], state, emit_time, emit_time_increment) do
    Logger.info "Resending packet..."
    emit_packet!(packet, state.emitter, emit_time)
    resend_packets(packets, state, emit_time + emit_time_increment, emit_time_increment)
  end

  defp resend_packets([], _state, _emit_time, _emit_time_increment) do
  end

  defp send_next_packet(state) do
    {packets, packet_number} = next_packet(1, state)
    state = %S{state | packet_number: packet_number}
    state = send_packets(packets, state)
    state
  end

  defp fast_send_packets([packet | packets], state) do
    state = emit_packet(packet, buffer_interval(state.stream_interval), state)
    fast_send_packets(packets, state)
  end

  defp fast_send_packets([], %S{} = state) do
    state
  end

  defp send_packets([packet | packets], state) do
    state = send_packet(packet, state)
    send_packets(packets, state)
  end

  defp send_packets([], state) do
    state
  end

  defp send_packet(packet, %S{stream_interval: interval} = state) do
    emit_packet(packet, interval, state)
  end

  defp emit_packet(:stop, _increment_emit, state) do
    finish(state)
  end

  defp emit_packet(packet, increment_emit, %S{emit_time: emit_time} = state) do
    emitted_packet = packet |> timestamp_packet(state)
                            |> emit_packet!(state.emitter, emit_time)

    %S{ state |
      in_flight: [emitted_packet | state.in_flight],
      emit_time: emit_time + increment_emit
    } |> monitor_in_flight
  end

  defp emit_packet!({timestamp, source_id, data}, emitter, emit_time) do
    {:emitter, emitter} = Otis.Broadcaster.Emitter.emit(emitter, emit_time, {timestamp, data})
    {emitter, timestamp, source_id, data}
  end

  defp monitor_in_flight(state) do
    {unplayed, played} = state |> partition_in_flight
    monitor_source(played, %S{ state | in_flight: unplayed })
  end

  defp partition_in_flight(state) do
    time = current_time(state)
    Enum.partition state.in_flight, fn({_, timestamp, _, _}) ->
      timestamp > time
    end
  end

  defp monitor_source([], state) do
    state
  end
  defp monitor_source([{_, _, source_id, _} | packets], %S{source_id: nil} = state) do
    source_changed(source_id, nil, state)
    monitor_source(packets, %S{ state | source_id:  source_id })
  end
  defp monitor_source([{_, _, source_id, _} | packets], %S{source_id: source_id} = state) do
    monitor_source(packets, state)
  end
  defp monitor_source([{_, _, new_source_id, _} | packets], %S{source_id: old_source_id} = state)
  when new_source_id != old_source_id do
    source_changed(new_source_id, old_source_id, state)
    monitor_source(packets, %S{ state | source_id:  new_source_id })
  end

  defp source_changed(new_source_id, old_source_id, state) do
    Logger.info "SOURCE CHANGED #{ old_source_id } => #{ new_source_id }"
    Otis.State.Events.notify({:source_changed, state.id, old_source_id, new_source_id})
  end

  # Take all the in flight packets that we know haven't been played
  # and send them back to the buffer so that if we resume playback
  # the audio starts where it left off rather than losing a buffer's worth
  # of audio.
  defp rebuffer_in_flight(%{audio_stream: audio_stream} = state) do
    packets = state |> unplayed_packets |> Enum.map(fn({_, _, source_id, data}) -> {source_id, data} end)
    GenServer.cast(audio_stream, {:rebuffer, packets})
    %S{ state | in_flight: [] }
  end

  defp bufferable_packets(state) do
    state
    |> unplayed_packets(current_time(state) + state.latency)
    |> Enum.map(fn({_, timestamp, source_id, data}) -> {timestamp, source_id, data} end)
    |> Enum.reverse
  end

  defp unplayed_packets(state) do
    time = current_time(state)
    state |> unplayed_packets(time)
  end

  defp unplayed_packets(state, time) do
    Enum.reject(state.in_flight, fn({_, timestamp, _, _}) -> timestamp <= time end)
  end

  defp stop_inflight_packets(state) do
    do_stop_inflight_packets(state.in_flight)
  end

  defp do_stop_inflight_packets([]) do
  end

  defp do_stop_inflight_packets([{emitter, timestamp, _source_id, _data} = _packet | packets]) do
    Otis.Zone.Emitter.discard!(emitter, timestamp)
    do_stop_inflight_packets(packets)
  end

  defp timestamp_packet({packet_number, source_id, data}, state) do
    {timestamp_for_packet(packet_number, state), source_id, data}
  end

  defp timestamp_for_packet(packet_number, %S{start_time: start_time, stream_interval: interval, latency: latency} = _state) do
    timestamp_for_packet(packet_number, start_time, interval, latency)
  end

  def timestamp_for_packet(packet_number, start_time, interval, latency) do
    start_time + latency + (packet_number * interval)
  end

  defp next_packet(n, %S{audio_stream: audio_stream, packet_number: packet_number} = _state) do
    next_packet(n, [], packet_number, audio_stream)
  end

  defp next_packet(0, buf, packet_number, _audio_stream) do
    {Enum.reverse(buf), packet_number}
  end

  defp next_packet(n, buf, packet_number, audio_stream) do
    case Otis.AudioStream.frame(audio_stream) do
      {:ok, source_id, packet} ->
        buf = [{packet_number, source_id, packet} | buf]
        next_packet(n - 1, buf, packet_number + 1, audio_stream)
      :stopped ->
        buf = [:stop | buf]
        next_packet(0, buf, packet_number + 1, audio_stream)
    end
  end

  defp current_time(%S{} = state) do
    Otis.Broadcaster.Clock.time(state.clock)
  end
  defp current_time(clock) do
    Otis.Broadcaster.Clock.time(clock)
  end
end
