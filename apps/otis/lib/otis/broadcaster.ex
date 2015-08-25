defmodule Otis.Broadcaster do
  @moduledoc """
  The real heart of the system, takes a zone and then links its audio stream to
  its recievers
  """

  use GenServer

  def start_link(zone, interval) do
    GenServer.start_link(__MODULE__, %{ zone: zone, target_interval: interval, interval: interval, state: :play, last_signal: nil })
  end

  def init(%{ interval: interval } = state) do
    _schedule(self, interval)
    {:ok, state}
  end

  def play(broadcaster) do
    GenServer.cast(broadcaster, :play)
  end

  def stop(broadcaster) do
    GenServer.cast(broadcaster, :stop)
  end

  def handle_cast(:play, %{interval: interval, state: :stop} = bc) do
    _schedule(self, interval)
    {:noreply, %{ bc | state: :play  }}
  end

  def handle_cast(:play, %{state: :play} = bc) do
    # don't do anything
    {:noreply, bc}
  end

  def handle_cast(:stop, bc) do
    IO.inspect [:broadcaster, :stop]
    {:stop, :normal, %{ bc | state: :stop  }}
  end

  def handle_info(:broadcast, %{ zone: zone, state: :play} = bc) do
    bc = schedule(self, bc, now_in_milliseconds)
    GenServer.cast(zone, :broadcast)
    {:noreply, bc}
  end

  def handle_info(:broadcast, %{state: :stop} = bc) do
    {:noreply, bc}
  end

  # defp duration_of(action) do
  #   start = now_in_milliseconds
  #   result = action.()
  #   finish = now_in_milliseconds
  #   {result, finish - start}
  # end

  defp now_in_milliseconds do
    :erlang.monotonic_time :milli_seconds
  end

  defp schedule(pid, %{interval: interval, last_signal: nil} = bc, now) do
    _schedule(pid, interval)
    %{ bc | last_signal: now}
  end

  defp schedule(pid, %{target_interval: target_interval, last_signal: last_signal, interval: interval} = bc, now) do
    gap = now - last_signal
    interval = case gap do
      _ when gap < target_interval -> interval + 1
      _ when gap == target_interval -> interval
      _ when gap > target_interval -> interval - 1
    end
    # IO.inspect [Integer.to_string(gap), Integer.to_string(interval)]
    _schedule(pid, interval)
    %{ bc | last_signal: now, interval: interval}
  end

  def _schedule(pid, interval) do
    Process.send_after(pid, :broadcast, interval)
  end
end
