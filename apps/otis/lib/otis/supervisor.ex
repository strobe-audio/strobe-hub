defmodule Otis.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [])
  end

  def init(:ok) do
    IO.inspect [:Otis_Supervisor, :init]
    children = [
      supervisor(Otis.Zones.Supervisor, [[name: Otis.Zones.Supervisor]]),
      worker(Otis.Zones, []),
      supervisor(Otis.Receivers.Supervisor, []),
      worker(Otis.Receivers, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end

