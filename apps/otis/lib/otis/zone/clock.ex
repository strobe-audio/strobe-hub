defmodule Otis.Zone.Clock do
  use     GenServer
  require Monotonic

  defmodule S do
    defstruct [:stream_interval, :poll_interval, :broadcasters, :timer]
  end

  defstruct [:pid]

  import GenServer, only: [cast: 2]

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
    {:ok, ref} = schedule_emit(poll_interval)
    state = %S{
      stream_interval: stream_interval,
      poll_interval: poll_interval,
      broadcasters: [],
      timer: ref
    }
    {:ok, state}
  end

  def handle_cast({:start, broadcaster, latency, buffer_size}, %S{broadcasters: broadcasters} = state) do
    cast(broadcaster, {:start, now, latency, buffer_size})
    {:noreply, %S{ state | broadcasters: [ broadcaster | broadcasters] }}
  end

  def handle_cast({:stop, broadcaster}, %S{broadcasters: broadcasters} = state) do
    Otis.Broadcaster.stop_broadcaster(broadcaster, now)
    {:noreply, %S{ state | broadcasters: List.delete(broadcasters, broadcaster) }}
  end

  def handle_cast({:skip, broadcaster}, %S{broadcasters: broadcasters} = state) do
    Otis.Broadcaster.skip_broadcaster(broadcaster, now)
    {:noreply, %S{ state | broadcasters: List.delete(broadcasters, broadcaster) }}
  end

  def handle_info(:tick, %S{broadcasters: broadcasters} = state) do
    time = now
    Enum.each broadcasters, fn(broadcaster) ->
      cast(broadcaster, {:emit, time, state.poll_interval * 1000})
    end
    {:noreply, state}
  end

  defp schedule_emit(poll_interval) do
    :timer.send_interval(poll_interval, self, :tick)
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
end
