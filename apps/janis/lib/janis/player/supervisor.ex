defmodule Janis.Player.Supervisor do
  use Supervisor

  def start_link({ip, port}) do
    Supervisor.start_link(__MODULE__, {ip, port})
  end

  def init({ip, port}) do
    children = [
      worker(Janis.Player.Buffer, [Janis.Player.Buffer]),
      worker(Janis.Player.Socket, [{ip, port}, Janis.Player.Buffer]),
      worker(Janis.Player.Player, [Janis.Player.Buffer]),
    ]
    supervise(children, strategy: :one_for_all)
  end
end
