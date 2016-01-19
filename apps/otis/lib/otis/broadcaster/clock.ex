defprotocol Otis.Broadcaster.Clock do
  @doc """
  Start the clock with the given params..
  """
  def start(clock, broadcaster, latency, buffer_size)
  # def skip()
  # def stop()
end

defimpl Otis.Broadcaster.Clock, for: Otis.Zone.Clock do
  def start(clock, broadcaster, latency, buffer_size) do
    GenServer.cast(clock.pid, {:start, broadcaster, latency, buffer_size})
    clock
  end
end
