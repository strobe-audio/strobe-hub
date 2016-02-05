defmodule Otis.Zones.Supervisor do
  use Supervisor

  @supervisor_name Otis.Zones.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def init(:ok) do
    children = [
      worker(Otis.Zone, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_zone(id, name) do
    start_zone(@supervisor_name, id, name)
  end

  def stop_zone(pid) do
    stop_zone(@supervisor_name, pid)
  end

  def start_zone(supervisor, id, name) do
    Supervisor.start_child(supervisor, [id, name])
  end
  def stop_zone(supervisor, pid) do
    Supervisor.terminate_child(supervisor, pid)
  end
end
