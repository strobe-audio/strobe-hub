defmodule Otis.Zone.Controller do
  use     GenServer
  require Monotonic

  defmodule S do
    defstruct [
      :stream_interval,
      :poll_interval,
      :broadcaster,
      :clock,
      :next_tick_us,
      :timer
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
    {:ok, pid} = Otis.Controllers.start_controller(stream_interval, poll_interval)
    %__MODULE__{ pid: pid }
  end

  def start_link(stream_interval, poll_interval) do
    GenServer.start_link(__MODULE__, [stream_interval, poll_interval], [])
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

  def handle_cast(:done, %S{timer: nil} = state) do
    {:noreply, state}
  end
  def handle_cast(:done, %S{timer: timer} = state) do
    Process.cancel_timer(timer)
    {:noreply, %S{state|timer: nil}}
  end

  def handle_cast({:start, broadcaster, latency, buffer_size}, %S{clock: clock} = state) do
    {:noreply, start(broadcaster, latency, buffer_size, state)}
  end

  def handle_cast({:stop, broadcaster}, %S{broadcaster: broadcaster} = state) do
    Otis.Broadcaster.stop_broadcaster(broadcaster)
    {:noreply, %S{ state | broadcaster: nil }}
  end

  def handle_cast({:skip, broadcaster}, %S{broadcaster: broadcaster} = state) do
    Otis.Broadcaster.skip_broadcaster(broadcaster)
    {:noreply, %S{ state | broadcaster: nil }}
  end

  def handle_info(:tick, %S{broadcaster: nil} = state) do
    {:noreply, state}
  end
  def handle_info(:tick, %S{broadcaster: broadcaster} = state) do
    tick(Process.alive?(broadcaster), state)
  end
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, %S{ state | broadcaster: nil}}
  end

  def start(broadcaster, latency, buffer_size, %S{clock: clock} = state) do
    Process.monitor(broadcaster)
    call(broadcaster, {:start, clock, latency, buffer_size})
    %S{ state | broadcaster: broadcaster, next_tick_us: now } |> schedule_emit
  end

  defp tick(true, %S{broadcaster: broadcaster} = state) do
    cast(broadcaster, {:emit, state.poll_interval})
    {:noreply, schedule_emit(state) }
  end
  defp tick(false, %S{broadcaster: broadcaster} = state) do
    {:noreply, %S{state | broadcaster: nil} }
  end

  defp schedule_emit(state) do
    state |> increment_tick |> do_schedule_emit
  end

  defp do_schedule_emit(state) do
    ref = Process.send_after(self, :tick, interval_duration(state))
    %S{state | timer: ref}
  end

  defp interval_duration(state) do
    max(round((state.next_tick_us - now) / 1000), 0)
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
