defmodule Otis.Zone.Controller do
  use     GenServer
  require Monotonic

  defmodule S do
    defstruct [
      :stream_interval,
      :poll_interval,
      :broadcaster,
      :clock,
      :next_tick_us
    ]
  end

  defstruct [:pid]

  import GenServer, only: [cast: 2, call: 2]

  def default_poll_interval(stream_interval) do
    round(stream_interval/4)
  end

  def new(stream_interval) do
    new(stream_interval, default_poll_interval(stream_interval))
  end
  def new(stream_interval, poll_interval) do
    {:ok, pid} = start_link(stream_interval, poll_interval)
    %__MODULE__{ pid: pid }
  end

  def start_link(stream_interval, poll_interval) do
    GenServer.start_link(__MODULE__, [stream_interval, poll_interval])
  end

  def init([stream_interval, poll_interval]) do
    Process.flag(:priority, :high)
    state = %S{
      stream_interval: stream_interval,
      poll_interval: poll_interval,
      broadcaster: nil,
      clock: Otis.Zone.Clock.new
    }
    {:ok, state}
  end

  def handle_cast({:start, broadcaster, latency, buffer_size}, %S{broadcaster: nil, clock: clock} = state) do
    call(broadcaster, {:start, clock, latency, buffer_size})
    state = %S{ state | broadcaster: broadcaster, next_tick_us: now } |> schedule_emit
    {:noreply, state}
  end

  def handle_cast({:stop, broadcaster}, %S{broadcaster: broadcaster} = state) do
    Otis.Broadcaster.stop_broadcaster(broadcaster)
    {:noreply, %S{ state | broadcaster: nil }}
  end

  def handle_cast({:skip, broadcaster}, %S{broadcaster: broadcaster} = state) do
    Otis.Broadcaster.skip_broadcaster(broadcaster)
    {:noreply, %S{ state | broadcaster: nil }}
  end

  def handle_cast(:done, state) do
    {:noreply, %S{ state | broadcaster: nil }}
  end

  def handle_info(:tick, %S{broadcaster: nil} = state) do
    {:noreply, state}
  end
  def handle_info(:tick, %S{broadcaster: broadcaster} = state) do
    call(broadcaster, {:emit, state.poll_interval})
    {:noreply, schedule_emit(state) }
  end

  defp schedule_emit(state) do
    state |> increment_tick |> do_schedule_emit
  end

  defp do_schedule_emit(state) do
    duration = round((state.next_tick_us - now) / 1000)
    Process.send_after(self, :tick, duration)
    state
  end

  defp increment_tick(state) do
    %S{ state | next_tick_us: state.next_tick_us + state.poll_interval }
  end

  defp now, do: Monotonic.microseconds
end

defimpl Otis.Broadcaster.Controller, for: Otis.Zone.Controller do
  def start(controller, broadcaster, latency, buffer_size) do
    GenServer.cast(controller.pid, {:start, broadcaster, latency, buffer_size})
    controller
  end
  def stop(controller, broadcaster) do
    GenServer.cast(controller.pid, {:stop, broadcaster})
    controller
  end
  def skip(controller, broadcaster) do
    GenServer.cast(controller.pid, {:skip, broadcaster})
    controller
  end
  def done(controller) do
    GenServer.cast(controller.pid, :done)
    controller
  end
end
