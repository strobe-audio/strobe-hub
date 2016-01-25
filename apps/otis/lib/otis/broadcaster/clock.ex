defprotocol Otis.Broadcaster.Clock do
  @doc """
  Start the clock with the given params..
  """
  def start(clock, broadcaster, latency, buffer_size)
  def stop(clock, broadcaster)
  def skip(clock, broadcaster)
  def done(clock)
end

