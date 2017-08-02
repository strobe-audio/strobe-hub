defmodule Otis.Pipeline.Clock do
  use     GenServer
  require Monotonic

  defmodule S do
    @moduledoc false

    defstruct [:timer, :broadcaster, :t, :d]
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
    {:ok, %S{
      d: 0,
    }}
  end

  def handle_call({:start, broadcaster, interval_ms}, _from, state) do
    state = send_after({:tick, interval_ms}, interval_ms, state)
    {:reply, {:ok, now()}, %S{state | broadcaster: broadcaster, t: now()}}
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
    t = now()
    tick(state.broadcaster, t)
    state = schedule_tick(interval_ms, t, state)
    {:noreply, %S{state | t: t}}
  end

  # This attempts to keep the actual interval as close to the desired value as
  # possible. This is not strictly necessary as the broadcaster calculates the
  # number of packets to send based on the (current time - start time) but the
  # tendency is for this timer to be late, requiring > 1 packet to be sent, so
  # I'd prefer to keep the bandwidth as flat as possible rather than send
  # frequent bursts. This algorithm tends to result in extraneous tick calls
  # rather than requiring > 1 packets per interval.
  defp schedule_tick(interval_ms, t, %S{d: d} = state) do
    delta = (t - state.t) - (interval_ms * 1000)

    d = case delta do
      _ when delta > 0 -> d + 1
      _ when delta < 0 -> d - 1
      _ -> d
    end

    state = %S{state | d: d}
    send_after({:tick, interval_ms}, interval_ms - d, state)
  end
  defp send_after(msg, interval_ms, state) do
    timer = Process.send_after(self(), msg, interval_ms)
    %S{state | timer: timer}
  end

  defp now, do: Monotonic.microseconds()
end
