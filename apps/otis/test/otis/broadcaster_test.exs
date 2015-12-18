defmodule Otis.Test.ArrayAudioStream do
  use GenServer

  def start_link(packets) do
    Kernel.apply GenServer, :start_link, [__MODULE__, packets]
  end

  def init(packets) do
    {:ok, %{ packets: packets }}
  end

  def handle_call(:frame, _from, state) do
    { packet, state } = next_packet(state)
    {:reply, packet, state}
  end

  def next_packet(%{packets: []} = state) do
    { :stopped, %{ state | packets: [] } }
  end
  def next_packet(%{packets: [packet | packets]} = state) do
    { {:ok, "source-1", packet}, %{ state | packets: packets } }
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
end

defmodule Otis.BroadcasterTest do
  use   ExUnit.Case, async: true

  setup do
    {:ok, zone} = Otis.Zones.start_zone(UUID.uuid1(), "Zone")
    packets = (1..100) |> Enum.map(&Integer.to_string(&1, 10))
    # - a audio stream that emits known packets
    {:ok, stream} = Otis.Test.ArrayAudioStream.start_link(packets)
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

    {:ok, broadcaster} = Otis.Zone.Broadcaster.start_link(opts)

    # save a handy timestamp calculation function
    timestamp = &Otis.Zone.Broadcaster.timestamp_for_packet(&1, clock.start_time, opts.stream_interval, clock.latency)

    {:ok,
      zone: zone,
      packets: packets,
      stream: stream,
      emitter: emitter,
      clock: clock,
      opts: opts,
      broadcaster: broadcaster,
      timestamp: timestamp,
      latency: 0
    }
  end
  test "it sends the right number of buffer packets", state do
    buffer_size = 5

    _clock = Otis.Broadcaster.Clock.start(state.clock, state.broadcaster, state.latency, buffer_size)

    Enum.each 0..(buffer_size - 1), fn(n) ->
      ts = state.timestamp.(n)
      {:ok, packet} = Enum.fetch state.packets, n
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
end
