defmodule Otis.Zone.Clock do
  use     GenServer
  require Monotonic

  defmodule S do
    defstruct [:stream_interval, :poll_interval, :broadcaster, :timer]
  end

  defstruct [:pid]

  import GenServer, only: [cast: 2, call: 2]

  def default_poll_interval(stream_interval) do
    round((stream_interval/4) / 1000)
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
    }
    {:ok, state}
  end

  def handle_cast({:start, broadcaster, latency, buffer_size}, %S{broadcaster: nil} = state) do
    call(broadcaster, {:start, now, latency, buffer_size})
    {:ok, ref} = schedule_emit(state.poll_interval)
    {:noreply, %S{ state | broadcaster: broadcaster, timer: ref }}
  end

  def handle_cast({:stop, broadcaster}, %S{broadcaster: broadcaster} = state) do
    Otis.Broadcaster.stop_broadcaster(broadcaster, now)
    cancel_emit(state)
    {:noreply, %S{ state | broadcaster: nil }}
  end

  def handle_cast({:skip, broadcaster}, %S{broadcaster: broadcaster} = state) do
    Otis.Broadcaster.skip_broadcaster(broadcaster, now)
    cancel_emit(state)
    {:noreply, %S{ state | broadcaster: nil }}
  end

  def handle_cast(:done, %S{broadcaster: broadcaster} = state) do
    cancel_emit(state)
    {:noreply, %S{ state | broadcaster: nil }}
  end

  def handle_info(:tick, %S{broadcaster: broadcaster} = state) do
    cast(broadcaster, {:emit, now, state.poll_interval * 1000})
    {:noreply, state}
  end

  defp schedule_emit(poll_interval) do
    :timer.send_interval(poll_interval, self, :tick)
  end

  defp cancel_emit(state) do
    :timer.cancel(state.timer)
  end

  defp now, do: Monotonic.microseconds
end

defimpl Otis.Broadcaster.Clock, for: Otis.Zone.Clock do
  def start(clock, broadcaster, latency, buffer_size) do
    GenServer.cast(clock.pid, {:start, broadcaster, latency, buffer_size})
    clock
  end
  def stop(clock, broadcaster) do
    GenServer.cast(clock.pid, {:stop, broadcaster})
    clock
  end
  def skip(clock, broadcaster) do
    GenServer.cast(clock.pid, {:skip, broadcaster})
    clock
  end
  def done(clock) do
    GenServer.cast(clock.pid, :done)
    clock
  end
end
