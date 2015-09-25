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
    IO.inspect [:start_broadcaster, opts]
    Supervisor.start_child(supervisor, [opts])
  end

  def stop_broadcaster(broadcaster) do
    stop_broadcaster(@supervisor_name, broadcaster)
  end

  def stop_broadcaster(supervisor, broadcaster) do
    GenServer.cast(broadcaster, :stop)
  end

  def init(:ok) do
    children = [
      worker(Otis.Zone.Broadcaster, [], [restart: :transient])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end




