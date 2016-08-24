defprotocol Otis.Broadcaster.Emitter do
  @doc """
  Emit the given {timestamp, data} packet on the given socket at the
  given time

  Retuns a handle to the emitter that can be used for cancelling packets.
  """
  def emit(emitter, emit_time, packet)
  def stop(emitter)
end
