defmodule Otis.Broadcaster do
  use Supervisor

  @supervisor_name Otis.Broadcaster

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def start_broadcaster(opts) do
    start_broadcaster(@supervisor_name, opts)
  end

  def start_broadcaster(supervisor, opts) do
    Supervisor.start_child(supervisor, [opts])
  end

  def stream_finished(broadcaster) do
    stop_broadcaster!(broadcaster, :stream_finished)
  end

  def stop_broadcaster(broadcaster, time) do
    stop_broadcaster!(broadcaster, {:stop, time})
  end

  def skip_broadcaster(broadcaster, time) do
    stop_broadcaster!(broadcaster, {:skip, time})
  end

  def stop_broadcaster!(broadcaster, reason) do
    GenServer.cast(broadcaster, {:stop, reason})
  end

  def init(:ok) do
    children = [
      worker(Otis.Zone.Broadcaster, [], [restart: :transient])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
