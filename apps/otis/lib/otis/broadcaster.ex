defmodule Otis.Broadcaster do
  @moduledoc """
  The real heart of the system, takes a zone and then links its audio stream to
  its recievers
  """

  require Logger
  use     GenServer
  alias   Otis.Broadcaster.Bandwidth

  def start_link(zone, interval) do
    bw = Bandwidth.new(interval, Otis.stream_bytes_per_step, 3)
    GenServer.start_link(__MODULE__, %{ zone: zone, target_interval: interval, interval: interval - 1, state: :play, last_signal: nil, bandwidth: bw  })
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

  def handle_cast(:stop, %{bandwidth: bw} = bc) do
    Logger.info "Bandwidth #{Bandwidth.stats(bw)}"
    {:stop, :normal, %{ bc | state: :stop  }}
  end

  def handle_info(:broadcast, %{ zone: zone, state: :play, bandwidth: bw} = bc) do
    # Use call so the actual time it takes to send the message, marshal & send
    # the data is factored into the timings here.
    GenServer.call(zone, :broadcast)
    bw = Bandwidth.sent(bw)
    bc = schedule(self, %{ bc | bandwidth: bw }, now_in_milliseconds)
    {:noreply, bc}
  end

  def handle_info(:broadcast, %{state: :stop} = bc) do
    {:noreply, bc}
  end

  defp now_in_milliseconds do
    :erlang.monotonic_time :milli_seconds
  end

  defp schedule(pid, %{interval: interval, last_signal: nil} = bc, now) do
    _schedule(pid, interval)
    %{ bc | last_signal: now}
  end

  defp schedule(pid, %{target_interval: target_interval, last_signal: last_signal, interval: interval, bandwidth: bw} = bc, now) do
    gap = now - last_signal
    interval = case gap do
      _ when gap < target_interval -> interval + 1
      _ when gap == target_interval -> interval
      _ when gap > target_interval -> interval - 1
    end
    {:ok, bw, interval} = Bandwidth.adjust(bw, interval)
    _schedule(pid, interval)
    %{ bc | last_signal: now, interval: interval, bandwidth: bw}
  end

  def _schedule(pid, interval) do
    Process.send_after(pid, :broadcast, interval)
  end
end
