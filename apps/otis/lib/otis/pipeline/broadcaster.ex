defmodule Otis.Pipeline.Broadcaster do
  use GenServer

  require Logger

  alias Otis.Packet
  alias Otis.Receiver
  alias Otis.Pipeline.Clock
  alias Otis.Pipeline.Config
  alias Otis.Pipeline.Hub
  alias Otis.Pipeline.Producer

  defmodule S do
    @moduledoc false

    defstruct [
      :id,
      :channel,
      :hub,
      :clock,
      :config,
      :t0,
      :offset_us,
      :offset_n,
      :packet_duration_us,
      n: 0,
      c: 0,
      inflight: [],
      buffer: [],
      rendition_id: nil,
      started: false,
      playing: false,
    ]
  end

  def start_link(id, channel, hub, clock, config) do
    GenServer.start_link(__MODULE__, [id, channel, hub, clock, config])
  end

  def start(broadcaster) do
    GenServer.cast(broadcaster, :start)
  end

  def pause(broadcaster) do
    GenServer.cast(broadcaster, :pause)
  end

  def skip(broadcaster, rendition_id) do
    GenServer.cast(broadcaster, {:skip, rendition_id})
  end

  def init([id, channel, hub, clock, config]) do
    Otis.Receivers.Channels.subscribe(__MODULE__, id)
    {:ok, %S{
      id: id,
      channel: channel,
      hub: hub,
      clock: clock,
      config: config,
      packet_duration_us: config.packet_duration_ms * 1000,
    }}
  end

  def handle_info({:receiver_left, _}, state) do
    {:noreply, state}
  end
  def handle_info({:receiver_joined, [_id, receiver]}, state) do
    {:ok, time} = Clock.time(state.clock)
    playable = playable_packets(time, state)
    Receiver.stop(receiver)
    Receiver.send_packets(receiver, playable)
    {:noreply, state}
  end

  # Useful in tests to make sure we've done with things like buffering receivers
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  def handle_cast(:start, state) do
    state = start(&clock_start_time/1, state)
    notify_channel(state, :broadcaster_start)
    {:noreply, %S{state | started: true, playing: true}}
  end

  def handle_cast(:pause, state) do
    {:ok, time} = Clock.stop(state.clock)
    Otis.Receivers.Channels.stop(state.id)
    state = case Producer.pause(state.hub) do
      :ok ->
        {_played, unplayed} = Enum.split_with(state.inflight, &Packet.played?(&1, time))
        buffer = unplayed |> Enum.map(&Packet.reset!/1) |> Enum.reverse()
        %S{state | n: 0, buffer: buffer, inflight: []}
      :stop ->
        %S{state | n: 0, buffer: [], inflight: []}
    end
    {:noreply, %S{state | playing: false}}
  end

  def handle_cast({:tick, time}, state) do
    packets = packet_count_at_time(time, state) - state.n
    state = send_packets(state, time, packets)
    {:noreply, state}
  end

  def handle_cast({:skip, rendition_id}, %S{playing: false} = state) do
    Hub.skip(state.hub, rendition_id)
    {:noreply, %S{state | buffer: []}}
  end
  def handle_cast({:skip, rendition_id}, state) do
    Otis.Receivers.Channels.stop(state.id)
    Hub.skip(state.hub, rendition_id)
    state = start(&clock_time/1, %S{ state | buffer: [] })
    {:noreply, state}
  end


  defp start(time, %S{buffer: []} = state) do
    case Producer.next(state.hub) do
      :done ->
        start_with_time(time, state)
      {:ok, packet} ->
        start_with_time(time, %S{state| buffer: [ packet | state.buffer ]})
    end
  end
  defp start(time, state) do
    start_with_time(time, state)
  end

  defp start_with_time(time, state) do
    {:ok, t0} = time.(state)
    offset_us = (state.config.base_latency_ms * 1000) + Otis.Receivers.Channels.latency(state.id)
    offset_n = Config.receiver_buffer_packets(state.config)
    buffer_receivers(%S{state | t0: t0, offset_us: offset_us, offset_n: offset_n, n: 0, inflight: []}, t0)
  end

  defp clock_start_time(state) do
    Clock.start(state.clock, self(), state.config.packet_duration_ms)
  end

  defp clock_time(state) do
    Clock.time(state.clock)
  end

  defp packet_count_at_time(time, state) do
    duration = time - state.t0
    round(Float.floor(state.offset_n + (duration / state.packet_duration_us)))
  end

  defp play_time(time, state, margin_ms) do
    time + ((state.config.base_latency_ms + margin_ms) * 1000) + Otis.Receivers.Channels.latency(state.id)
  end

  defp buffer_receivers(state, time) do
    send_packets(state, time, state.offset_n)
  end

  defp send_packets(state, _time, n) when n <= 0 do
    state
  end
  defp send_packets(state, time, n) do
    state |> build_packets(n, []) |> broadcast_packets() |> monitor_packets(time)
  end

  defp monitor_packets({state, packets}, time) do
    inflight = Enum.concat(Enum.reverse(packets), state.inflight)
    {played, unplayed} = Enum.split_with(inflight, &Packet.played?(&1, time))
    state = state |> monitor_rendition(played, unplayed) |> monitor_progress(played)
    state = state |> monitor_status(unplayed)
    %S{state | inflight: unplayed }
  end

  defp monitor_status(state, []) do
    notify_channel(state, :broadcaster_stop)
    {:ok, _time} = Clock.stop(state.clock)
    %S{state | playing: false}
  end
  defp monitor_status(state, _unplayed) do
    state
  end

  defp monitor_rendition(state, _played, [] = _unplayed) do
    %S{ state | rendition_id: nil } |> notify_rendition_change(state.rendition_id, nil)
  end
  defp monitor_rendition(state, [], _unplayed) do
    state
  end
  defp monitor_rendition(%S{rendition_id: nil} = state, [packet | _rest], _unplayed) do
    %S{state|rendition_id: packet.rendition_id} |> notify_rendition_change(nil, packet.rendition_id)
  end
  defp monitor_rendition(%S{rendition_id: rendition_id} = state, [%Packet{rendition_id: rendition_id} | _rest], _unplayed) do
    state
  end
  defp monitor_rendition(%S{rendition_id: rendition_id} = state, [packet | _rest], _unplayed) do
    %S{state|rendition_id: packet.rendition_id} |> notify_rendition_change(rendition_id, packet.rendition_id)
  end

  defp notify_rendition_change(state, nil, nil) do
    state
  end
  defp notify_rendition_change(state, old_id, new_id) do
    Otis.Events.notify(:playlist, :advance, [state.id, old_id, new_id])
    state
  end

  defp monitor_progress(state, played) do
    Enum.each(played, fn(packet) ->
      Otis.Events.notify(:rendition, :progress, [state.id, packet.rendition_id, packet.offset_ms, packet.source_duration])
    end)
    state
  end

  defp playable_packets(time, state) do
    t = play_time(time, state, 50)
    {_, playable} = Enum.split_with(state.inflight, &Packet.played?(&1, t))
    Enum.reverse(playable)
  end

  defp broadcast_packets({state, packets}) do
    Otis.Receivers.Channels.send_packets(state.id, packets)
    {state, packets}
  end

  defp build_packets(state, 0, packets) do
    {state, Enum.reverse(packets)}
  end
  defp build_packets(%S{buffer: [packet|buffer]} = state, n, packets) do
    send_packet(%S{state| buffer: buffer}, n, packets, {:ok, packet})
  end
  defp build_packets(state, n, packets) do
    send_packet(state, n, packets, Producer.next(state.hub))
  end

  defp send_packet(state, _n, packets, :done) do
    build_packets(state, 0, packets)
  end
  defp send_packet(state, n, packets, {:ok, packet}) do
    packet = Packet.timestamp(packet, timestamp(state), state.c)
    build_packets(%S{state | c: state.c + 1, n: state.n + 1}, n - 1, [packet | packets])
  end

  defp timestamp(state) do
    (state.packet_duration_us * state.n) + state.t0 + state.offset_us
  end

  defp notify_channel(state, event) do
    send(state.channel, event)
  end
end
