
defmodule Otis.Zone.Broadcaster do
  use     GenServer
  require Logger

  @buffer_latency 5_000 # music starts playing after this many microseconds
  @buffer_size    2      # players hold this many packets (more or less)


  defmodule S do
    defstruct zone: nil,
              audio_stream: nil,
              socket: nil,
              latency: 0.0,
              stream_interval: 0,
              start_time: 0,
              packet_number: 0,
              in_flight: [],
              emit_time: 0
  end

  # This basically takes a zone / audio source and translates it into a set of
  # timestamped packets. It then queues this to send to the clients.
  #
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
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def init(opts) do
    Logger.info "Starting broadcaster #{inspect opts}"
    # Logger.disable(self)
    state = %S{
      zone: opts[:zone],
      audio_stream: opts[:audio_stream],
      socket: opts[:socket],
      latency: opts[:latency],
      stream_interval: opts[:stream_interval]
    }
    GenServer.cast(self, :start)
    {:ok, state}
  end

  def handle_cast(:start, state) do
    state = start(state)
    {:noreply, state}
  end

  def handle_cast({:stop, :stop}, state) do
    # TODO: send back the in-flight packets to the audio stream (or the zone?)
    # TODO: find all my emitters and tell them to stop too...
    state = stop!(state)
    {:stop, {:shutdown, :stopped}, state}
  end

  def handle_cast({:stop, :stream_finished}, state) do
    # I can just stop the broadcaster process here because this message
    # originated in the emit_packet method so everything that needs to have
    # been sent to the players has already been sent
    {:stop, {:shutdown, :stopped}, state}
  end

  def handle_info(:emit, state) do
    state = potentially_emit(state)
    state = schedule_emit(state)
    {:noreply, state}
  end

  # Now I have the first n packets:
  # - convert them from { seq. number, data } to { timestamp, data } @done
  # - schedule them to be sent in < buffer interval intervals @done
  # - save them into the `in_flight` list @done
  # - schedule some kind of ticker to start posting packets at the defined interval
  defp start(state) do
    Logger.info ">>>>>>>>>>>>> Fast send start......"
    {packets, packet_number} = next_packet(@buffer_size, state)
    state = %S{state | start_time: current_time, emit_time: current_time, packet_number: packet_number}
    state = fast_send_packets(packets, state)
    Logger.info "<<<<<<<<<<<<< Fast send over ......"
    state = schedule_emit(state)
    state
  end

  @doc """
    The 'stop' button has been pressed so pull back anything we were about to send
  """
  defp stop!(state) do
    Logger.info "Stopping broadcaster..."
    stop_inflight_packets(state)
    rebuffer_in_flight(state)
    state
  end

  @doc "The audio stream has finished, so just exit"
  defp finish(%S{zone: zone} = state) do
    Logger.info "Stopping broadcaster..."
    Otis.Zone.stream_finished(zone)
    state
  end

  defp potentially_emit(%S{packet_number: packet_number, emit_time: emit_time} = state) do
    ci = (check_interval(state) * 1000)
    next_check = current_time + ci
    # Logger.debug "Potentially emit #{packet_number} #{emit_time}, #{next_check} #{next_check - emit_time}"
    diff = (next_check - emit_time)
    if (abs(diff) < ci) || (diff > 0) do
      state = send_next_packet(state)
    end
    state
  end

  defp send_next_packet(%S{} = state) do
    {packets, packet_number} = next_packet(1, state)
    state = %S{state | packet_number: packet_number}
    state = send_packets(packets, state)
    state
  end

  defp check_interval(%S{stream_interval: interval}) do
    round((interval / 4) / 1000)
  end

  defp schedule_emit(state) do
    Process.send_after(self, :emit, check_interval(state))
    state
  end

  defp fast_send_packets([packet | packets], %S{stream_interval: interval, emit_time: emit_time} = state) do
    state = emit_packet(packet, 5_000, state)
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

  defp emit_packet(packet, increment_emit, %{socket: socket, in_flight: in_flight, start_time: start_time, emit_time: emit_time} = state) do
    {_play_time, _data} = timestamped_packet = timestamp_packet(packet, state)
    emitter = :poolboy.checkout(Otis.EmitterPool)
    now = current_time
    # Logger.debug "Emit packet emit: #{emit_time - now}; play: #{_play_time - start_time}"
    Otis.Zone.Emitter.emit(emitter, emit_time, timestamped_packet, socket)
    packet_in_flight = { emitter, _play_time, _data }
    in_flight = [packet_in_flight | in_flight] |> trim_in_flight
    Logger.debug "Inflight #{length(in_flight)} packets"
    %S{ state | in_flight: in_flight, emit_time: emit_time + increment_emit}
  end

  defp trim_in_flight(packets) do
    now = current_time
    Enum.filter packets, fn({_emitter, timestamp, _data}) ->
      timestamp > now
    end
  end

  defp rebuffer_in_flight(state) do
    Logger.warn "!! Implement Broadcaster.rebuffer_in_flight/1"
  end

  defp stop_inflight_packets(%S{in_flight: in_flight} = _state) do
    stop_inflight_packets(in_flight)
  end

  defp stop_inflight_packets([]) do
  end

  defp stop_inflight_packets([{emitter, timestamp, _data} = _packet | packets]) do
    Otis.Zone.Emitter.discard!(emitter, timestamp)
    stop_inflight_packets(packets)
  end

  defp timestamp_packet({packet_number, _data}, state) do
    {timestamp_for_packet(packet_number, state), _data}
  end

  defp timestamp_for_packet(packet_number, %S{start_time: start_time, stream_interval: interval, latency: latency} = _state) do
    timestamp_for_packet(packet_number, start_time, interval, latency)
  end

  defp timestamp_for_packet(packet_number, start_time, interval, latency) do
    start_time + @buffer_latency + latency + ((packet_number + 1) * interval)
  end

  defp next_packet(n, %S{audio_stream: audio_stream, packet_number: packet_number} = _state) do
    next_packet(n, [], packet_number, audio_stream)
  end

  defp next_packet(0, buf, packet_number, _audio_stream) do
    {Enum.reverse(buf), packet_number}
  end

  defp next_packet(n, buf, packet_number, audio_stream) do
    case Otis.AudioStream.frame(audio_stream) do
      {:ok, packet} ->
        buf = [{packet_number, packet} | buf]
        next_packet(n - 1, buf, packet_number + 1, audio_stream)
      :stopped ->
        buf = [:stop | buf]
        next_packet(0, buf, packet_number + 1, audio_stream)
    end
  end

  defp current_time do
    :erlang.monotonic_time(:micro_seconds)
  end
end
