defmodule Otis.Test.ArrayAudioStream do
  use   GenServer

  def start_link(sources, parent) do
    Kernel.apply GenServer, :start_link, [__MODULE__, {sources, parent}]
  end

  def init({sources, parent}) do
    {:ok, %{ sources: sources, packets: [], packet: nil, parent: parent }}
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
    next_packet(%{ state | packets: packets, packet: TestUtils.packet(source_id), sources: sources})
  end
  def next_packet(%{packets: [data | packets], packet: packet} = state) do
    { {:ok, Otis.Packet.attach(packet, data)}, %{ state | packets: packets, packet: Otis.Packet.step(packet) } }
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
  def handle_call({:step, new_time}, _from, {_time}) do
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

  def time(%__MODULE__{time: time} = _controller) do
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
    try do
      GenServer.call(broadcaster, {:emit, interval})
    catch
      :exit, _reason -> nil
    end
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
  use   ExUnit.Case
  alias Otis.Packet

  setup do
    MessagingHandler.attach

    latency    = 500
    start_time = 5000

    zone_id = Otis.uuid
    {:ok, zone} = Otis.Zones.create(zone_id, "Zone")
    packets1 = (1..10) |> Enum.map(&Integer.to_string(&1, 10))
    source1 = [Otis.uuid, packets1]
    packets2 = (11..20) |> Enum.map(&Integer.to_string(&1, 10))
    source2 = [Otis.uuid, packets2]
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
    timestamp = &Otis.Zone.Broadcaster.timestamp_for_packet_number(&1, start_time, opts.stream_interval, latency)
    emit_time = &(start_time + (&1 * opts.stream_interval))


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
    p = TestUtils.packet(source_id1)
    Enum.reduce packets1, p, fn(data, packet) ->
      frame = Otis.AudioStream.frame(stream)
      packet = Otis.Packet.attach(packet, data)
      assert {:ok, packet} == frame
      Otis.Packet.step(packet)
    end
    [source_id2, packets2] = source2
    p = TestUtils.packet(source_id2)
    Enum.reduce packets2, p, fn(data, packet) ->
      frame = Otis.AudioStream.frame(stream)
      packet = Otis.Packet.attach(packet, data)
      assert {:ok, packet} == frame
      Otis.Packet.step(packet)
    end
    :stopped = Otis.AudioStream.frame(stream)
  end

  test "it sends the right number of buffer packets", %{source1: source1} = context do
    buffer_size = 5
    [source_id1, packets1] = source1

    _clock = Otis.Broadcaster.Controller.start(context.clock, context.broadcaster, context.latency, buffer_size)

    packets = Enum.take(packets1, buffer_size - 1) |> Enum.zip(0..(buffer_size - 1))

    Enum.reduce packets, TestUtils.packet(source_id1), fn({data, n}, packet) ->
      ts = context.timestamp.(n)
      et = context.start_time + (n * Otis.Zone.Broadcaster.buffer_interval(context.opts.stream_interval))
      p = packet |> Packet.attach(data) |> Packet.timestamp(ts, n)
      assert_receive {:emit, ^et, ^p}, "Not received #{n}"
      Packet.step(packet)
    end
  end

  test "it sends audio packets when stepped", context do
    buffer_size = 5
    poll_interval = round(context.opts.stream_interval / 2)

    clock = Otis.Broadcaster.Controller.start(context.clock, context.broadcaster, context.latency, buffer_size)

    Enum.each 0..(buffer_size - 1), fn(n) ->
      time = context.timestamp.(n)
      assert_receive {:emit, _, %Packet{timestamp: ^time}}, 1000, "Not received buffer packet #{n}"
    end

    n = buffer_size
    ts = context.timestamp.(n)

    time = context.start_time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200

    time = time + poll_interval
    emit_time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, ^emit_time, %Packet{timestamp: ^ts}}, 200

    n = n + 1
    ts = context.timestamp.(n)

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200

    time = time + poll_interval
    emit_time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, ^emit_time, %Packet{timestamp: ^ts}}, 200

    n = n + 1
    ts = context.timestamp.(n)

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200

    time = time + poll_interval
    emit_time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, ^emit_time, %Packet{timestamp: ^ts}}, 200

    n = n + 1
    ts = context.timestamp.(n)

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200

    time = time + poll_interval
    emit_time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, ^emit_time, %Packet{timestamp: ^ts}}, 200

    n = n + 1
    ts = context.timestamp.(n)

    time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    refute_receive {:emit, _, _}, 200

    time = time + poll_interval
    emit_time = time + poll_interval
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, ^emit_time, %Packet{timestamp: ^ts}}, 200
  end

  test "it broadcasts a source change event", %{ zone_id: zone_id, source1: source1, source2: source2 } = context do

    buffer_size = 5
    poll_interval = round(context.opts.stream_interval / 1)

    clock = Otis.Broadcaster.Controller.start(context.clock, context.broadcaster, context.latency, buffer_size)

    [source_id1, _] = source1
    [source_id2, _] = source2

    time = context.timestamp.(0)
    Otis.Test.SteppingController.step(clock, time, poll_interval)
    assert_receive {:emit, _, _}, 200


    assert_receive {:source_changed, ^zone_id, nil, ^source_id1}, 200


    Enum.each 2..10, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200
    end

    assert_receive {:source_changed, ^zone_id, ^source_id1, ^source_id2}, 200

    Enum.each 10..19, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200
    end
  end

  test "it broadcasts a stream finished event", %{ zone_id: zone_id } = context do
    buffer_size = 5
    poll_interval = round(context.opts.stream_interval / 1)

    clock = Otis.Broadcaster.Controller.start(context.clock, context.broadcaster, context.latency, buffer_size)

    time = context.timestamp.(0)

    Enum.each 1..10, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    Enum.each 11..20, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    Otis.Test.SteppingController.step(clock, time + (21 * poll_interval), poll_interval)
    assert_receive {:zone_finished, ^zone_id}, 200
  end

  test "it broadcasts a final source change event", %{ zone_id: zone_id, source2: source2 } = context do
    buffer_size = 5
    poll_interval = round(context.opts.stream_interval / 1)

    clock = Otis.Broadcaster.Controller.start(context.clock, context.broadcaster, context.latency, buffer_size)

    time = context.timestamp.(0)

    Enum.each 1..10, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    Enum.each 11..20, fn(n) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
    end

    Otis.Test.SteppingController.step(clock, time + (21 * poll_interval), poll_interval)
    assert_receive {:zone_finished, ^zone_id}, 200

    [source_id2, _] = source2

    assert_receive {:source_changed, ^zone_id, ^source_id2, nil}, 200
  end

  test "it broadcasts a stream stop event", %{ zone_id: zone_id } = context do
    buffer_size = 5
    _clock = Otis.Broadcaster.Controller.start(context.clock, context.broadcaster, context.latency, buffer_size)
    _clock = Otis.Test.SteppingController.stop(context.clock, context.broadcaster)
    assert_receive {:zone_stop, ^zone_id}, 200
  end

  test "it rebuffers in-flight packets when stopped", context do
    buffer_size = 5
    poll_interval = round(context.opts.stream_interval / 4)
    steps = 25
    time = context.start_time
    controller = Otis.Broadcaster.Controller.start(context.clock, context.broadcaster, context.latency, buffer_size)

    Enum.each 1..steps, fn(n) ->
      Otis.Test.SteppingController.step(controller, time + (n * poll_interval), poll_interval)
    end

    ts = context.timestamp.(7)
    assert_receive {:emit, _, %Packet{timestamp: ^ts, data: "8"}}, 1000

    Otis.Test.SteppingClock.step(context.clock.clock, context.timestamp.(7) + 1)

    Otis.Broadcaster.Controller.stop(context.clock, context.broadcaster)
    assert_receive {:rebuffer, packets}, 200

    assert length(packets) == 4, "Expected 4 packets but got #{ length(packets) }"

    [p1, p2, p3, p4] = packets
    [source_id1, packets1] = context.source1
    [source_id2, packets2] = context.source2

    packets1_1 = Enum.fetch!(packets1, -2)
    packets1_2 = Enum.fetch!(packets1, -1)
    packets2_1 = Enum.fetch!(packets2, 0)
    packets2_2 = Enum.fetch!(packets2, 1)

    assert %Otis.Packet{Otis.Packet.step(TestUtils.packet(source_id2)) | data: packets2_2 } == p1
    assert %Otis.Packet{TestUtils.packet(source_id2) | data: packets2_1 } == p2
    assert %Otis.Packet{TestUtils.packet(source_id1) | source_index: 9, offset_ms: 180, data: packets1_2} == p3
    assert %Otis.Packet{TestUtils.packet(source_id1) | source_index: 8, offset_ms: 160, data: packets1_1} == p4
  end

  test "it broadcasts source playback position", %{ zone_id: zone_id, source1: source1 } = context do
    buffer_size = 5
    poll_interval = round(context.opts.stream_interval / 1)

    clock = Otis.Broadcaster.Controller.start(context.clock, context.broadcaster, context.latency, buffer_size)

    time = context.timestamp.(0)

    [source_id1, _] = source1

    Enum.reduce 1..10, TestUtils.packet(source_id1), fn(n, packet) ->
      Otis.Test.SteppingController.step(clock, time + (n * poll_interval), poll_interval)
      assert_receive {:emit, _, _}, 200, "Not received #{n}"
      %{ offset_ms: position } = packet
      assert_receive {:source_progress, ^zone_id, ^source_id1, ^position, 60_000}
      Otis.Packet.step(packet)
    end
  end
end
