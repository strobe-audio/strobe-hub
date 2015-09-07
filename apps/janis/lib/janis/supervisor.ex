defmodule Janis.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(Janis.Player, []),
      worker(Janis.Monitor, []),
      worker(Janis.Resources, []),
      # worker(Janis.Looper, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
