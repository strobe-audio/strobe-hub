defmodule Otis.Zone.Controller do
  use     GenServer
  require Monotonic

  defmodule S do
    defstruct [
      :stream_interval,
      :poll_interval,
      :tick_interval,
      :broadcaster,
      :clock,
      :timer,
      :last_tick_us
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
      tick_interval: round(poll_interval / 1000),
      broadcaster: nil,
      clock: Otis.Zone.Clock.new
    }
    {:ok, state}
  end

  def handle_cast({:start, broadcaster, latency, buffer_size}, %S{broadcaster: nil, clock: clock} = state) do
    call(broadcaster, :prebuffer)
    cast(broadcaster, {:start, clock, latency, buffer_size})
    {:ok, ref} = schedule_emit(state.tick_interval)
    # ref = nil
    # Process.send_after(self, :tick, state.poll_interval / 1000)
    # schedule_emit(state.tick_interval)
    {:noreply, %S{ state | broadcaster: broadcaster, timer: ref, last_tick_us: now }}
  end

  def handle_cast({:stop, broadcaster}, %S{broadcaster: broadcaster} = state) do
    Otis.Broadcaster.stop_broadcaster(broadcaster)
    {:noreply, %S{ cancel_emit(state) | broadcaster: nil, timer: nil }}
  end

  def handle_cast({:skip, broadcaster}, %S{broadcaster: broadcaster} = state) do
    Otis.Broadcaster.skip_broadcaster(broadcaster)
    {:noreply, %S{ cancel_emit(state) | broadcaster: nil, timer: nil }}
  end

  def handle_cast(:done, %S{broadcaster: broadcaster} = state) do
    {:noreply, %S{ cancel_emit(state) | broadcaster: nil, timer: nil }}
  end

  def handle_info(:tick, %S{broadcaster: nil} = state) do
    {:noreply, cancel_emit(state)}
  end
  def handle_info(:tick, %S{broadcaster: broadcaster} = state) do
    cast(broadcaster, {:emit, round(state.tick_interval * 1.2)})
    {:noreply, %S{state | last_tick_us: now}}
  end

  defp schedule_emit(tick_interval_ms) do
    :timer.send_interval(tick_interval_ms - 2, self, :tick)
    # Process.send_after(self, :tick, tick_interval_ms)
  end

  defp cancel_emit(state) do
    :timer.cancel(state.timer)
    %S{ state | timer: nil }
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
