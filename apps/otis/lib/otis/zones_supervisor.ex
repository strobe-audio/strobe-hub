defmodule Otis.Zones.Supervisor do
  use Supervisor

  def start_link(opts) do
    IO.inspect [:zone, :supervisor, opts]
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def start_zone(supervisor, id, name) do
    Supervisor.start_child(supervisor, [id, name])
  end

  def init(:ok) do
    children = [
      worker(Otis.Zone, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
