defprotocol Otis.Broadcaster.Emitter do
  @doc """
  Emit the given {timestamp, data} packet on the given socket at the
  given time

  Retuns a handle to the emitter that can be used for cancelling packets.
  """
  def emit(emitter, emit_time, packet)
  def stop(emitter)
end

defimpl Otis.Broadcaster.Emitter, for: Otis.Zone.Emitter do
  def emit(emitter, emit_time, {timestamp, data}) do
    pid = :poolboy.checkout(emitter.pool)
    Otis.Zone.Emitter.emit(pid, emit_time, timestamp, emitter.socket)
    {:emitter, pid}
  end

  def stop(emitter) do
    Otis.Zone.Socket.stop(emitter.socket)
  end
end
