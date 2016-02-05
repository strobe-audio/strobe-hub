defmodule Otis.Controllers do
  use Supervisor

  @supervisor_name Otis.Controllers.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def init(:ok) do
    children = [
      worker(Otis.Zone.Controller, [], [restart: :transient, shutdown: :brutal_kill])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_controller(stream_interval, poll_interval) do
    start_controller(@supervisor_name, stream_interval, poll_interval)
  end

  def start_controller(supervisor, stream_interval, poll_interval) do
    IO.inspect [:start_controller, supervisor, stream_interval, poll_interval]
    Supervisor.start_child(supervisor, [stream_interval, poll_interval])
  end
end

