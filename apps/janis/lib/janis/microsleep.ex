defmodule Janis.Microsleep do
  # see this thread for the original Erlang implementation:
  # http://erlang.org/pipermail/erlang-questions/2007-March/025702.html

  @jitter 5

  def microsleep(microseconds) do
    target = Janis.microseconds + microseconds
    adj = microseconds - @jitter
    case adj > 3000 do
      true ->
        :timer.sleep(milliseconds(adj) - 1)
      false ->
        :ok
    end
    {finish, loops} = busywait_until(target, 1)
    {finish - target, loops}
  end

  defp milliseconds(microseconds) do
    div(microseconds, 1000)
  end

  defp busywait_until(target, loops) do
    case Janis.microseconds do
      time when time >= target ->
        {time, loops}
      _ ->
        :erlang.yield()
        busywait_until(target, 1 + loops)
    end
  end

  # sanity check the implementation
  def test(milliseconds \\ 20) do
    {accuracy, loops} = microsleep(milliseconds*1000)
    IO.puts "Jitter: #{accuracy} µs, iterations #{loops}"
  end

  def test2(ms) do
    start = :erlang.monotonic_time(:milli_seconds)
    :timer.sleep(ms)
    finish = :erlang.monotonic_time(:milli_seconds)
    IO.puts "Elapsed #{finish - start} ms"
  end
end
