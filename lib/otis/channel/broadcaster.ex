
defmodule Otis.Channel.Broadcaster do
  @moduledoc """
  This takes a channel and audio source and translates it into a set of
  timestamped packets. It then queues this to send to the clients.
  """

  use     GenServer
  require Logger
  alias   Otis.Packet

  # initial packets are sent out with this interval
  @fast_emit_interval 10_000


  defmodule S do
    @moduledoc "State for the broadcaster genserver"
    defstruct [
      id: nil,
      channel: nil,
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
  # - The broadcaster gets a receiver latency from the channel when it starts, it
  #   should use that to calculate the broadcast latency (time between start &
  #   first packet play)
  # - Broadcaster is responsible for pulling the packets from the stream, not the channel
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

  def start_link(opts, name) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def buffer_receiver(broadcaster, channel, receiver) do
    GenServer.cast(broadcaster, {:buffer_receiver, channel, receiver})
  end


  def init(opts) do
    Logger.info "Starting broadcaster #{inspect opts}"
    # Logger.disable(self)
    state = struct(%S{}, opts)
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

  # This stops the broadcaster quickly (sending a <<STOP>> to the receivers)
  # but pushes back any unplayed packets to the source stream so that when
  # we press play again, we start from where we left off.
  def handle_cast({:stop, :stop}, state) do
    {:stop, {:shutdown, :stopped}, stop!(state)}
  end

  # XXX: pre-buffering new receivers is very difficult to do without strange
  # behavioural artifacts which are much worse than just having to wait a couple
  # of seconds for the music to start.
  # I will re-visit this at some point.
  def handle_cast({:buffer_receiver, channel, receiver}, state) do
    # packets = state |> bufferable_packets
    # # We want to re-send the suitable unplayed packets without affecting the
    # # playback of existing receivers, so do it in a separate process. The
    # # resend_packets mechanism doesn't affect this process's state so it's safe
    # # to do it in parallel.
    # spawn(fn ->
    #   resend_packets(packets, state)
    #   # Once we're done, tell the channel to finish off...
    #   Otis.Channel.receiver_buffered(channel, receiver)
    # end)
    Otis.Channel.receiver_buffered(channel, receiver)
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
    Otis.State.Events.notify({:channel_stop, [state.id]})
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

  # The audio stream has finished, so tell the channel we're done so it can shut
  # us down properly
  defp finish(%S{in_flight: [], state: :stopped} = state) do
    state
  end
  defp finish(%S{in_flight: [], channel: channel, state: :play} = state) do
    Logger.debug "Stream finished"
    source_changed(nil, state.source_id, state)
    Otis.State.Events.notify({:channel_finished, [state.id]})
    Otis.Channel.stream_finished(channel)
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
      send_next_packet(state)
    else
      state
    end
  end

  # XXX: uncomment when re-enabling fast-buffering of new receivers
  # defp resend_packets(packets, state) do
  #   # Perhaps what I need to do is figure out how much time I have and fit in
  #   # as many packets as I can without compromising on the deliverability of
  #   # those packets
  #   resend_packets(packets, state.emitter, current_time(state) + 1_000, 500)
  # end
  # defp resend_packets([packet | packets], emitter, emit_time, emit_time_increment) do
  #   Logger.info "Resending packet... #{ packet.source_id }/#{inspect packet.source_index}"
  #   emit_packet!(packet, emitter, emit_time)
  #   resend_packets(packets, emitter, emit_time + emit_time_increment, emit_time_increment)
  # end
  #
  # defp resend_packets([], _emitter, _emit_time, _emit_time_increment) do
  # end

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

  defp emit_packet!(packet, emitter, emit_time) do
    {:emitter, emitter} = Otis.Broadcaster.Emitter.emit(emitter, emit_time, packet)
    Packet.emit(packet, emitter)
  end

  defp monitor_in_flight(state) do
    {unplayed, played} = state |> partition_in_flight
    %S{ state | in_flight: unplayed }
    |> monitor_source(played)
    |> update_progress(played)
  end

  defp partition_in_flight(state) do
    time = current_time(state)
    Enum.partition state.in_flight, &(Packet.unplayed?(&1, time))
  end

  defp monitor_source(state, []) do
    state
  end
  defp monitor_source(%S{source_id: nil} = state, [%Packet{source_id: source_id} | packets]) do
    source_changed(source_id, nil, state)
    monitor_source(%S{ state | source_id:  source_id }, packets)
  end
  defp monitor_source(%S{source_id: source_id} = state, [%Packet{source_id: source_id} | packets]) do
    monitor_source(state, packets)
  end
  defp monitor_source(%S{source_id: old_source_id} = state, [%Packet{source_id: new_source_id} | packets])
  when new_source_id != old_source_id do
    source_changed(new_source_id, old_source_id, state)
    monitor_source(%S{ state | source_id:  new_source_id }, packets)
  end

  defp update_progress(state, played) do
    Enum.each(played, fn(packet) ->
      Otis.State.Events.notify({:rendition_progress, [state.id, packet.source_id, packet.offset_ms, packet.duration_ms]})
    end)
    state
  end

  defp source_changed(new_rendition_id, old_rendition_id, state) do
    Logger.info "SOURCE CHANGED #{ old_rendition_id } => #{ new_rendition_id }"
    confirmation = Enum.find(state.in_flight, &Packet.from_source?(&1, old_rendition_id))
    if is_nil(confirmation) do
      Otis.State.Events.notify({:rendition_changed, [state.id, old_rendition_id, new_rendition_id]})
    else
      Logger.error "Invalid source changed event"
      Logger.error inspect(Enum.map(state.in_flight, fn(packet) -> packet end), limit: 1000, width: 200)
    end
  end

  # Take all the in flight packets that we know haven't been played
  # and send them back to the buffer so that if we resume playback
  # the audio starts where it left off rather than losing a buffer's worth
  # of audio.
  defp rebuffer_in_flight(%{audio_stream: audio_stream} = state) do
    packets = state |> unplayed_packets |> Enum.map(&Packet.reset!/1)
    GenServer.cast(audio_stream, {:rebuffer, packets})
    %S{ state | in_flight: [] }
  end

  # XXX: uncomment when re-enabling fast-buffering of new receivers
  # defp bufferable_packets(state) do
  #   state
  #   |> unplayed_packets(current_time(state) + state.latency)
  #   |> Enum.reverse
  # end

  defp unplayed_packets(state) do
    time = current_time(state)
    state |> unplayed_packets(time)
  end

  defp unplayed_packets(state, time) do
    state.in_flight |> Enum.reject(&Packet.played?(&1, time))
  end

  defp stop_inflight_packets(state) do
    do_stop_inflight_packets(state.in_flight)
  end

  defp do_stop_inflight_packets([]) do
  end

  defp do_stop_inflight_packets([packet | packets]) do
    Otis.Channel.Emitter.discard!(packet.emitter, packet.timestamp)
    do_stop_inflight_packets(packets)
  end

  defp timestamp_packet(packet, state) do
    Packet.timestamp(packet, packet_timestamp(packet, state))
  end

  defp packet_timestamp(packet, state) do
    timestamp_for_packet_number(packet.packet_number, state.start_time, state.stream_interval, state.latency)
  end

  def timestamp_for_packet_number(packet_number, start_time, stream_interval, latency) do
    start_time + latency + (packet_number * stream_interval)
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
        buf = [%Packet{packet | packet_number: packet_number} | buf]
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
