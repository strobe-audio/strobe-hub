defmodule Otis.Zones.Supervisor do
  use Supervisor

  @supervisor Otis.Zones.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor)
  end

  def init(:ok) do
    children = [
      worker(Otis.Zone, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_zone(id, config) do
    start_zone(@supervisor, id, config)
  end
  def start_zone(supervisor, id, config) do
    Supervisor.start_child(supervisor, [id, config])
  end

  def stop_zone(pid) do
    stop_zone(@supervisor, pid)
  end

  def stop_zone(supervisor, pid) do
    Supervisor.terminate_child(supervisor, pid)
  end
end
