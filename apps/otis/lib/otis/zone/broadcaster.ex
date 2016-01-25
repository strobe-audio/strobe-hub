
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
      zone: nil,
      audio_stream: nil,
      emitter: nil,
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

  def timestamp_for_packet(packet_number, start_time, interval, latency) do
    start_time + latency + (packet_number * interval)
  end

  def buffer_interval(stream_interval) do
    round(stream_interval / 4)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def init(opts) do
    Logger.info "Starting broadcaster #{inspect opts}"
    # Logger.disable(self)
    state = %S{
      zone: opts.zone,
      audio_stream: opts.audio_stream,
      emitter: opts.emitter,
      stream_interval: opts.stream_interval
    }
    {:ok, state}
  end

  def handle_call({:start, now, latency, buffer_size}, _from, state) do
    {:reply, :ok, start(now, latency, buffer_size, state)}
  end

  # This stops the broadcaster quickly (sending a <<STOP>> to the receivers)
  # but pushes back any unplayed packets to the source stream so that when
  # we press play again, we start from where we left off.
  def handle_cast({:stop, {:stop, time}}, state) do
    {:stop, {:shutdown, :stopped}, stop!(state, time)}
  end

  # This stops the broadcaster & drops any unsent packets
  # Used during track skipping
  def handle_cast({:stop, {:skip, time}}, state) do
    {:stop, {:shutdown, :stopped}, kill!(state, time)}
  end

  def handle_cast({:emit, time, interval}, state) do
    state |> potentially_emit(time, interval) |> monitor_finish
  end

  defp start(now, latency, buffer_size, state) do
    Logger.info ">>>>>>>>>>>>> Fast send start......"
    {packets, packet_number} = next_packet(buffer_size, state)
    state = %S{ state |
      start_time: now,
      emit_time: now,
      packet_number: packet_number,
      latency: latency
    }
    state = fast_send_packets(packets, state, now) |> monitor_in_flight(now)
    Logger.info "<<<<<<<<<<<<< Fast send over ......"
    state
  end

  defp kill!(state, time) do
    Logger.info "Killing broadcaster..."
    kill(state, time)
  end

  defp kill(state, time) do
    Otis.Broadcaster.Emitter.stop(state.emitter)
    stop_inflight_packets(state, time)
  end

  # The 'stop' button has been pressed so pull back anything we were about to
  # send
  defp stop!(state, time) do
    Logger.info "Stopping broadcaster..."
    {:ok, zone_id} = Otis.Zone.id(state.zone)
    Otis.State.Events.notify({:zone_stop, zone_id})
    kill(state, time)
    rebuffer_in_flight(state, time)
  end

  defp monitor_finish(%{state: :stopped} = state) do
    {:stop, {:shutdown, :stopped}, state}
  end
  defp monitor_finish(state) do
    {:noreply, state}
  end

  # The audio stream has finished, so tell the zone we're done so it can shut
  # us down properly
  defp finish(%S{in_flight: [], state: :stopped} = state, _time) do
    state
  end
  defp finish(%S{in_flight: [], zone: zone, state: :play} = state, _time) do
    Logger.debug "Stream finished"
    {:ok, zone_id} = Otis.Zone.id(zone)
    Otis.State.Events.notify({:zone_finished, zone_id})
    Otis.Zone.stream_finished(zone)
    %S{ state | state: :stopped }
  end
  defp finish(state, time) do
    monitor_in_flight(state, time)
  end

  defp potentially_emit(%S{emit_time: emit_time} = state, time, interval) do
    next_check = time + interval
    diff = (next_check - emit_time)
    if (abs(diff) < interval) || (diff > 0) do
      state = send_next_packet(state, time)
    end
    state
  end

  defp send_next_packet(%S{} = state, time) do
    {packets, packet_number} = next_packet(1, state)
    state = %S{state | packet_number: packet_number}
    state = send_packets(packets, state, time)
    state
  end

  defp fast_send_packets([packet | packets], state, time) do
    state = emit_packet(packet, buffer_interval(state.stream_interval), state, time)
    fast_send_packets(packets, state, time)
  end

  defp fast_send_packets([], %S{} = state, _time) do
    state
  end

  defp send_packets([packet | packets], state, time) do
    state = send_packet(packet, state, time)
    send_packets(packets, state, time)
  end

  defp send_packets([], state, _time) do
    state
  end

  defp send_packet(packet, %S{stream_interval: interval} = state, time) do
    emit_packet(packet, interval, state, time)
  end

  defp emit_packet(:stop, _increment_emit, state, time) do
    finish(state, time)
  end

  defp emit_packet(packet, increment_emit, %S{emit_time: emit_time} = state, time) do
    emitted_packet = packet |> timestamp_packet(state)
                            |> emit_packet!(state.emitter, emit_time)

    %S{ state |
      in_flight: [emitted_packet | state.in_flight],
      emit_time: emit_time + increment_emit
    } |> monitor_in_flight(time)
  end

  defp monitor_in_flight(state, time) do
    {unplayed, played} = state |> partition_in_flight(time)
    monitor_source(played, %S{ state | in_flight: unplayed })
  end

  defp emit_packet!({timestamp, source_id, data}, emitter, emit_time) do
    {:emitter, emitter} = Otis.Broadcaster.Emitter.emit(emitter, emit_time, {timestamp, data})
    {emitter, timestamp, source_id, data}
  end

  defp partition_in_flight(%S{in_flight: packets}, time) do
    Enum.partition packets, fn({_, timestamp, _, _}) ->
      timestamp > time
    end
  end

  defp monitor_source([], state) do
    state
  end
  defp monitor_source([{_, _, source_id, _} | packets], %S{source_id: nil} = state) do
    source_changed(source_id, state)
    monitor_source(packets, %S{ state | source_id:  source_id })
  end
  defp monitor_source([{_, _, source_id, _} | packets], %S{source_id: source_id} = state) do
    monitor_source(packets, state)
  end
  defp monitor_source([{_, _, source_id, _} | packets], %S{source_id: playing_source_id} = state)
  when source_id != playing_source_id do
    source_changed(source_id, state)
    monitor_source(packets, %S{ state | source_id:  source_id })
  end

  defp source_changed(new_source_id, state) do
    Logger.info "SOURCE CHANGED #{ new_source_id }"
    {:ok, zone_id} = Otis.Zone.id(state.zone)
    Otis.State.Events.notify({:source_changed, zone_id, new_source_id})
  end

  # Take all the in flight packets that we know haven't been played
  # and send them back to the buffer so that if we resume playback
  # the audio starts where it left off rather than losing a buffer's worth
  # of audio.
  defp rebuffer_in_flight(%{in_flight: in_flight, audio_stream: audio_stream} = state, time) do
    packets = in_flight |> unplayed_packets(time) |> Enum.map(fn({_, _, source_id, data}) -> {source_id, data} end)
    GenServer.cast(audio_stream, {:rebuffer, packets})
    %S{ state | in_flight: [] }
  end

  defp unplayed_packets(in_flight, time) do
    Enum.reject(in_flight, fn({_, timestamp, _, _}) -> timestamp <= time end)
  end

  defp stop_inflight_packets(%S{in_flight: in_flight} = _state, time) do
    stop_inflight_packets(in_flight, time)
  end

  defp stop_inflight_packets([], _time) do
  end

  defp stop_inflight_packets([{emitter, timestamp, _source_id, _data} = _packet | packets], time) do
    Otis.Zone.Emitter.discard!(emitter, timestamp)
    stop_inflight_packets(packets, time)
  end

  defp timestamp_packet({packet_number, source_id, data}, state) do
    {timestamp_for_packet(packet_number, state), source_id, data}
  end

  defp timestamp_for_packet(packet_number, %S{start_time: start_time, stream_interval: interval, latency: latency}) do
    timestamp_for_packet(packet_number, start_time, interval, latency)
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
end
