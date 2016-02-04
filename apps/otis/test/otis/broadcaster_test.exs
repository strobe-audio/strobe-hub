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
  use GenServer

  defstruct [:pid]

  def new(start_time) do
    {:ok, pid} = GenServer.start_link(Otis.Test.SteppingClock, start_time)
    %__MODULE__{pid: pid}
  end

  def step(clock, time) do
    GenServer.call(clock.pid, {:step, time})
  end

  def init(start_time) do
    {:ok, {start_time}}
  end
  def handle_call(:time, _from, {time}) do
    {:reply, time, {time}}
  end
  def handle_call({:step, new_time}, _from, {time}) do
    {:reply, :ok, {new_time}}
  end
end

defimpl Otis.Broadcaster.Clock, for: Otis.Test.SteppingClock do
  def time(clock) do
    GenServer.call(clock.pid, :time)
  end
end

defmodule Otis.Test.SteppingController do
  # use     GenServer

  defstruct [:broadcaster, :clock, start_time: 0, latency: 0, time: 0]

  def new(opts \\ [start_time: 0])
  def new(start_time: start_time) do
    clock = Otis.Test.SteppingClock.new(start_time)
    {:ok, %__MODULE__{start_time: start_time, time: start_time, clock: clock}}
  end

  def time(%__MODULE__{time: time} = controller) do
    time
  end

  def start(controller, broadcaster, latency, buffer_size) do
    GenServer.call(broadcaster, {:start, controller.clock, latency, buffer_size})
    %__MODULE__{ controller | broadcaster: broadcaster }
  end

  def stop(controller, broadcaster) do
    Otis.Broadcaster.stop_broadcaster(broadcaster)
    %__MODULE__{ controller | broadcaster: nil }
  end

  def done(controller) do
    controller
  end

  def step(%__MODULE__{broadcaster: nil} = controller, time, _interval) do
    :ok = Otis.Test.SteppingClock.step(controller.clock, time)
    %__MODULE__{ controller | time: time }
  end
  def step(%__MODULE__{broadcaster: broadcaster} = controller, time, interval) do
    :ok = Otis.Test.SteppingClock.step(controller.clock, time)
    GenServer.call(broadcaster, {:emit, interval})
    %__MODULE__{ controller | time: time }
  end
end

defimpl Otis.Broadcaster.Controller, for: Otis.Test.SteppingController do
  def start(controller, broadcaster, latency, buffer_size) do
    Otis.Test.SteppingController.start(controller, broadcaster, latency, buffer_size)
  end

  def stop(controller, broadcaster) do
    Otis.Test.SteppingController.stop(controller, broadcaster)
  end

  def skip(controller, broadcaster) do
    Otis.Test.SteppingController.stop(controller, broadcaster)
  end

  def done(controller) do
    Otis.Test.SteppingController.done(controller)
  end
end

defmodule Otis.BroadcasterTest do
  use   ExUnit.Case, async: true

  setup do
    latency    = 500
    start_time = 5000

    zone_id = Otis.uuid
    {:ok, zone} = Otis.Zones.start_zone(zone_id, "Zone")
    packets1 = (1..10) |> Enum.map(&Integer.to_string(&1, 10))
    source1 = ["source-1", packets1]
    packets2 = (11..20) |> Enum.map(&Integer.to_string(&1, 10))
    source2 = ["source-2", packets2]
    # - a audio stream that emits known packets
    {:ok, stream} = Otis.Test.ArrayAudioStream.start_link([source1, source2], self)
    # - an emitter impl that records the packets emitted (& when!)
    {:ok, emitter} = Otis.Test.RecordingEmitter.new(self)
    # - a clock implementation that is step-able
    {:ok, clock} = Otis.Test.SteppingController.new(start_time: start_time)

    opts = %{
      id: zone_id,
      zone: zone,
      audio_stream: stream,
      emitter: emitter,
      stream_interval: 10
    }

    {:ok, broadcaster} = Otis.Broadcaster.start_broadcaster(opts)

    # save a handy timestamp calculation function
    timestamp = &Otis.Zone.Broadcaster.timestamp_for_packet(&1, start_time, opts.stream_interval, latency)
    emit_time = &(start_time + (&1 * opts.stream_interval))

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
      emit_time: emit_time,
      latency: latency,
      start_time: start_time,
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

    _clock = Otis.Broadcaster.Controller.start(state.clock, state.broadcaster, state.latency, buffer_size)

    Enum.each 0..(buffer_size - 1), fn(n) ->
      ts = state.timestamp.(n)
      et = state.start_time + (n * Otis.Zone.Broadcaster.buffer_interval(state.opts.stream_interval))
      {:ok, packet} = Enum.fetch state.packets1, n
      expect = {:emit, et, {ts, packet}}
      assert_receive ^expect, 1000, "Not received #{n}"
    end
  end

  test "it sends audio packets when stepped", state do
    buffer_size = 5
    poll_interval = round(state.opts.stream_interval / 4)

    clock = Otis.Broadcaster.Controller.start(state.clock, state.broadcaster, state.latency, buffer_size)


    Enum.each 0..(buffer_size - 1), fn(n) ->
      assert_receive {:emit, _, _}, 1000, "Not received #{n}"
    end

    # EMIT
    time = state.timestamp.(1)
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, _, _}, 200, "Not received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    # EMIT
    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, _, _}, 200, "Not received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    # EMIT
    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, _, _}, 200, "Not received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200, "Received #{time}"

    # EMIT
    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, _, _}, 200, "Not received #{time}"
  end

  test "it broadcasts a source change event", %{ zone_id: zone_id, source1: source1, source2: source2 } = state do

    buffer_size = 5
    poll_interval = round(state.opts.stream_interval / 1)

    clock = Otis.Broadcaster.Controller.start(state.clock, state.broadcaster, state.latency, buffer_size)

    time = state.timestamp.(1)

    [source_id1, _] = source1
    [source_id2, _] = source2

    Otis.Test.SteppingController.step(clock, time + poll_interval, poll_interval)
    assert_receive {:emit, _, _}, 200
    assert_receive {:source_changed, ^zone_id, ^source_id1}, 200


    Enum.each 2..9, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    assert_receive {:source_changed, ^zone_id, ^source_id2}, 200

    Enum.each 10..20, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end
  end

  test "it broadcasts a stream finished event", %{ zone_id: zone_id } = state do

    buffer_size = 5
    poll_interval = round(state.opts.stream_interval / 1)

    clock = Otis.Broadcaster.Controller.start(state.clock, state.broadcaster, state.latency, buffer_size)

    time = state.timestamp.(1)

    Enum.each 1..9, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    Enum.each 10..20, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    Otis.Test.SteppingController.step(clock, time + (21 * poll_interval), poll_interval)
    assert_receive {:zone_finished, ^zone_id}, 200
  end

  test "it broadcasts a stream stop event", %{ zone_id: zone_id } = state do
    buffer_size = 5
    _clock = Otis.Broadcaster.Controller.start(state.clock, state.broadcaster, state.latency, buffer_size)
    _clock = Otis.Test.SteppingController.stop(state.clock, state.broadcaster)
    assert_receive {:zone_stop, ^zone_id}, 200
  end

  test "it rebuffers in-flight packets when stopped", state do
    buffer_size = 5
    poll_interval = round(state.opts.stream_interval / 4)
    steps = 25
    time = state.start_time
    controller = Otis.Broadcaster.Controller.start(state.clock, state.broadcaster, state.latency, buffer_size)

    Enum.each 1..steps, fn(n) ->
      Otis.Test.SteppingController.step(controller, time + (n * poll_interval), poll_interval)
    end

    ts = state.timestamp.(7)
    assert_receive {:emit, _, {^ts, "8"}}, 1000

    {:messages, messages} = Process.info(self, :messages)

    Otis.Test.SteppingClock.step(state.clock.clock, state.timestamp.(7) + 1)

    Otis.Broadcaster.Controller.stop(state.clock, state.broadcaster)
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
