defmodule Otis.Pipeline.Clock do
  require Monotonic

  defmodule S do
    @moduledoc false

    defstruct [:timer, :broadcaster]
  end

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def start(clock, broadcaster, interval_ms) do
    GenServer.call(clock, {:start, broadcaster, interval_ms})
  end
  def stop(clock) do
    GenServer.call(clock, :stop)
  end
  def time(clock) do
    GenServer.call(clock, :time)
  end

  def tick(broadcaster, time) do
    GenServer.cast(broadcaster, {:tick, time})
  end

  def init([]) do
    {:ok, %S{}}
  end

  def handle_call({:start, broadcaster, interval_ms}, _from, state) do
    state = schedule_tick(interval_ms, state)
    {:reply, {:ok, now()}, %S{ state | broadcaster: broadcaster }}
  end
  def handle_call(:time, _from, state) do
    {:reply, {:ok, now()}, state}
  end

  def handle_call(:stop, _from, state) do
    case state.timer do
      nil -> nil
      t -> Process.cancel_timer(t)
    end
    {:reply, {:ok, now()}, %S{state | timer: nil, broadcaster: nil}}
  end

  def handle_info({:tick, interval_ms}, state) do
    state = schedule_tick(interval_ms, state)
    tick(state.broadcaster, now())
    # GenServer.cast(state.broadcaster, {:tick, now()})
    {:noreply, state}
  end

  defp schedule_tick(interval_ms, state) do
    timer = Process.send_after(self(), {:tick, interval_ms}, interval_ms)
    {:reply, {:ok, now()}, %S{ state | timer: timer }}
  end

  defp now, do: Monotonic.microseconds()
end
