defmodule Otis.Channels.Supervisor do
  use Supervisor

  @supervisor Otis.Channels.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor)
  end

  def init(:ok) do
    children = [
      worker(Otis.Channel, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_channel(id, config) do
    start_channel(@supervisor, id, config)
  end
  def start_channel(supervisor, id, config) do
    Supervisor.start_child(supervisor, [id, config])
  end

  def stop_channel(pid) do
    stop_channel(@supervisor, pid)
  end

  def stop_channel(supervisor, pid) do
    Supervisor.terminate_child(supervisor, pid)
  end
end
