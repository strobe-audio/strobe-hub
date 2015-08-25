defmodule Otis.Receivers.Supervisor do
  use Supervisor

  @supervisor_name Otis.Receivers.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def start_receiver(id, name, conn) do
    start_receiver(@supervisor_name, id, name, conn)
  end

  def start_receiver(supervisor, id, name, conn) do
    Supervisor.start_child(supervisor, [id, name, conn])
  end

  def init(:ok) do
    children = [
      worker(Otis.Receiver, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end

