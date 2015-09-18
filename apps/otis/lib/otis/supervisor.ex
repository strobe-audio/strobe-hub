defmodule Otis.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [])
  end

  def init(:ok) do
    children = [
      worker(Otis.DNSSD, []),
      worker(Otis.SNTP, []),
      worker(Otis.State, []),
      worker(Otis.IPPool, [{224,24,4,0}]),
      supervisor(Otis.Zones.Supervisor, []),
      worker(Otis.Zones, []),
      supervisor(Otis.Receivers.Supervisor, []),
      worker(Otis.Receivers, []),
      worker(Otis.Startup, [Otis.State, Otis.Zones, Otis.Receivers], restart: :transient)
    ]
    supervise(children, strategy: :one_for_one)
  end
end

