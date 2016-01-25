defmodule Otis.Test.ArrayAudioStream do
  use GenServer

  def start_link(sources, parent) do
    Kernel.apply GenServer, :start_link, [__MODULE__, {sources, parent}]
  end

  def init({sources, parent}) do
    {:ok, %{ sources: sources, packets: [], source_id: nil, parent: parent }}
  end

  def handle_call(:frame, _from, state) do
    { packet, state } = next_packet(state)
    {:reply, packet, state}
  end

  def handle_cast({:rebuffer, packets}, %{parent: parent} = state) do
    send parent, {:rebuffer, packets}
    {:noreply, state}
  end

  def next_packet(%{packets: [], sources: []} = state) do
    { :stopped, %{ state | packets: [] } }
  end
  def next_packet(%{packets: [], sources: [source | sources]} = state) do
    [source_id, packets] = source
    next_packet(%{ state | packets: packets, source_id: source_id, sources: sources})
  end
  def next_packet(%{packets: [packet | packets], source_id: source_id} = state) do
    { {:ok, source_id, packet}, %{ state | packets: packets } }
  end
end

defmodule Otis.Test.RecordingEmitter do
  @moduledoc """
  Receives emit commands and just forwards them onto the given parent process.
  """

  defstruct [:parent]
  def new(parent) do
    {:ok, %__MODULE__{ parent: parent }}
  end
end

defimpl Otis.Broadcaster.Emitter, for: Otis.Test.RecordingEmitter do
  def emit(emitter, emit_time, packet) do
    send(emitter.parent, {:emit, emit_time, packet})
    {:emitter, emitter.parent}
  end
  def stop(emitter) do
    send(emitter.parent, :stop)
  end
end

defmodule Otis.Test.SteppingClock do
  # use     GenServer

  defstruct [:broadcaster, start_time: 0, latency: 0]

  def new(opts \\ [latency: 0])
  def new(latency: latency) do
    {:ok, %__MODULE__{latency: latency}}
  end

  def start(clock, broadcaster, latency, buffer_size) do
    GenServer.cast(broadcaster, {:start, clock.start_time, latency, buffer_size})
    %__MODULE__{ clock | broadcaster: broadcaster }
  end

  def stop(clock, broadcaster, time) do
    Otis.Broadcaster.stop_broadcaster(broadcaster, time)
    %__MODULE__{ clock | broadcaster: nil }
  end

  def step(%__MODULE__{broadcaster: nil} = clock, _time, _interval) do
    clock
  end
  def step(%__MODULE__{broadcaster: broadcaster} = clock, time, interval) do
    GenServer.cast(broadcaster, {:emit, time, interval})
    clock
  end
  # def start_link do
  #   GenServer.start_link(__MODULE__, [])
  # end
  #
  # def init([]) do
  #   {:ok, %{ broadcaster: nil, start_time: nil }}
  # end
  #
  # def handle_call({:start, broadcaster, buffer_size}, _from, state) do
  #   GenServer.cast(broadcaster, {:start, 0, buffer_size})
  #   {:reply, :ok, %{ state | broadcaster: broadcaster, start_time: 0 }}
  # end
end

defimpl Otis.Broadcaster.Clock, for: Otis.Test.SteppingClock do
  def start(clock, broadcaster, latency, buffer_size) do
    Otis.Test.SteppingClock.start(clock, broadcaster, latency, buffer_size)
  end
  def stop(clock, broadcaster) do
    Otis.Test.SteppingClock.stop(clock, broadcaster, 0)
  end
  def skip(clock, broadcaster) do
    Otis.Test.SteppingClock.stop(clock, broadcaster, 0)
  end
end

defmodule Otis.BroadcasterTest do
  use   ExUnit.Case, async: true

  setup do
    zone_id = UUID.uuid1()
    {:ok, zone} = Otis.Zones.start_zone(zone_id, "Zone")
    packets1 = (1..10) |> Enum.map(&Integer.to_string(&1, 10))
    source1 = [UUID.uuid1(), packets1]
    packets2 = (11..20) |> Enum.map(&Integer.to_string(&1, 10))
    source2 = [UUID.uuid1(), packets2]
    # - a audio stream that emits known packets
    {:ok, stream} = Otis.Test.ArrayAudioStream.start_link([source1, source2], self)
    # - an emitter impl that records the packets emitted (& when!)
    {:ok, emitter} = Otis.Test.RecordingEmitter.new(self)
    # - a clock implementation that is step-able
    {:ok, clock} = Otis.Test.SteppingClock.new(latency: 0)

    opts = %{
      zone: zone,
      audio_stream: stream,
      emitter: emitter,
      stream_interval: 10
    }

    {:ok, broadcaster} = Otis.Broadcaster.start_broadcaster(opts)

    # save a handy timestamp calculation function
    timestamp = &Otis.Zone.Broadcaster.timestamp_for_packet(&1, clock.start_time, opts.stream_interval, clock.latency)

    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    on_exit fn ->
      Otis.State.Events.remove_handler(MessagingHandler, self)
    end

    {:ok,
      zone_id: zone_id,
      zone: zone,
      packets1: packets1,
      packets2: packets2,
      stream: stream,
      emitter: emitter,
      clock: clock,
      opts: opts,
      broadcaster: broadcaster,
      timestamp: timestamp,
      latency: 0,
      source1: source1,
      source2: source2
    }
  end

  test "audio stream sends right packets & source ids", %{source1: source1, source2: source2, stream: stream} do
    [source_id1, packets1] = source1
    Enum.each packets1, fn(packet) ->
      {:ok, ^source_id1, ^packet} = Otis.AudioStream.frame(stream)
    end
    [source_id2, packets2] = source2
    Enum.each packets2, fn(packet) ->
      {:ok, ^source_id2, ^packet} = Otis.AudioStream.frame(stream)
    end
    :stopped = Otis.AudioStream.frame(stream)
  end

  test "it sends the right number of buffer packets", state do
    buffer_size = 5

    _clock = Otis.Broadcaster.Clock.start(state.clock, state.broadcaster, state.latency, buffer_size)

    Enum.each 0..(buffer_size - 1), fn(n) ->
      ts = state.timestamp.(n)
      {:ok, packet} = Enum.fetch state.packets1, n
      expect = {:emit, n * Otis.Zone.Broadcaster.buffer_interval(state.opts.stream_interval), {ts, packet}}
      assert_receive ^expect, 1000, "Not received #{n}"
    end
  end

  test "it sends audio packets when stepped", state do
    buffer_size = 5
    poll_interval = round(state.opts.stream_interval / 4)

    clock = Otis.Broadcaster.Clock.start(state.clock, state.broadcaster, state.latency, buffer_size)


    Enum.each 0..(buffer_size - 1), fn(n) ->
      assert_receive {:emit, _, _}, 1000, "Not received #{n}"
    end

    # EMIT
    time = state.timestamp.(1)
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    assert_receive {:emit, _, _}, 200, "Not received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    # EMIT
    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    assert_receive {:emit, _, _}, 200, "Not received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    # EMIT
    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    assert_receive {:emit, _, _}, 200, "Not received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    # EMIT
    time = time + poll_interval
    Otis.Test.SteppingClock.step(clock, time, poll_interval)
    assert_receive {:emit, _, _}, 200, "Not received #{time}"
  end

  test "it broadcasts a source change event", %{ zone_id: zone_id, source1: source1, source2: source2 } = state do

    buffer_size = 5
    poll_interval = round(state.opts.stream_interval / 1)

    clock = Otis.Broadcaster.Clock.start(state.clock, state.broadcaster, state.latency, buffer_size)

    time = state.timestamp.(1)

    [source_id1, _] = source1
    [source_id2, _] = source2

    Otis.Test.SteppingClock.step(clock, time + poll_interval, poll_interval)
    assert_receive {:emit, _, _}, 200
    assert_receive {:source_changed, ^zone_id, ^source_id1}, 200


    Enum.each 2..9, fn(n) ->
      Otis.Test.SteppingClock.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    assert_receive {:source_changed, ^zone_id, ^source_id2}, 200

    Enum.each 10..20, fn(n) ->
      Otis.Test.SteppingClock.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end
  end

  test "it broadcasts a stream finished event", %{ zone_id: zone_id } = state do

    buffer_size = 5
    poll_interval = round(state.opts.stream_interval / 1)

    clock = Otis.Broadcaster.Clock.start(state.clock, state.broadcaster, state.latency, buffer_size)

    time = state.timestamp.(1)

    Enum.each 1..9, fn(n) ->
      Otis.Test.SteppingClock.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    Enum.each 10..20, fn(n) ->
      Otis.Test.SteppingClock.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    Otis.Test.SteppingClock.step(clock, time + (21 * poll_interval), poll_interval)
    assert_receive {:zone_finished, ^zone_id}, 200
  end

  test "it broadcasts a stream stop event", %{ zone_id: zone_id } = state do
    buffer_size = 5
    _clock = Otis.Broadcaster.Clock.start(state.clock, state.broadcaster, state.latency, buffer_size)
    _clock = Otis.Test.SteppingClock.stop(state.clock, state.broadcaster, 0)
    assert_receive {:zone_stop, ^zone_id}, 200
  end

  test "it rebuffers in-flight packets when stopped", state do
    buffer_size = 5
    poll_interval = round(state.opts.stream_interval / 4)
    steps = 20
    time = state.timestamp.(1)
    clock = Otis.Broadcaster.Clock.start(state.clock, state.broadcaster, state.latency, buffer_size)
    Enum.each 1..steps, fn(n) ->
      Otis.Test.SteppingClock.step(clock, time + (n * poll_interval), poll_interval)
    end
    assert_receive {:emit, _, {70, "8"}}, 200
    Otis.Test.SteppingClock.stop(state.clock, state.broadcaster, time + (steps * poll_interval) + 1)
    assert_receive {:rebuffer, packets}, 200

    assert length(packets) == 4, "Expected 4 packets but got #{ length(packets) }"

    [p1, p2, p3, p4] = packets
    [source_id1, packets1] = state.source1
    [source_id2, packets2] = state.source2

    packets1_1 = Enum.fetch!(packets1, -2)
    packets1_2 = Enum.fetch!(packets1, -1)
    packets2_1 = Enum.fetch!(packets2, 0)
    packets2_2 = Enum.fetch!(packets2, 1)

    assert {source_id2, packets2_2} == p1
    assert {source_id2, packets2_1} == p2
    assert {source_id1, packets1_2} == p3
    assert {source_id1, packets1_1} == p4
  end
end
