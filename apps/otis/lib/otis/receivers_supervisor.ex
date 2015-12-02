defmodule Otis.Receivers.Supervisor do
  use Supervisor

  @supervisor_name Otis.Receivers.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def start_receiver(id, channel, connection_info) do
    start_receiver(@supervisor_name, channel, id, connection_info)
  end

  def start_receiver(supervisor, channel, id, connection_info) do
    Supervisor.start_child(supervisor, [channel, id, connection_info])
  end

  def init(:ok) do
    children = [
      # transient because we don't want to be restarted if we exit normally
      # i.e. when the remote receiver goes offline...
      worker(Otis.Receiver, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
