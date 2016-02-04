defprotocol Otis.Broadcaster.Controller do
  @doc """
  Start the controller with the given params..
  """
  def start(controller, broadcaster, latency, buffer_size)
  # FIXME: don't need broadcaster param here...
  def stop(controller, broadcaster)
  def skip(controller, broadcaster)
  def done(controller)
end

