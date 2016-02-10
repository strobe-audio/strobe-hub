defmodule Otis.Receivers.Supervisor do
  use Supervisor

  @supervisor Otis.Receivers.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor)
  end

  def start_receiver(id, zone, config, channel, connection_info) do
    start_receiver(@supervisor, id, zone, config, channel, connection_info)
  end

  def start_receiver(supervisor, id, zone, config, channel, connection_info) do
    Supervisor.start_child(supervisor, [id, zone, config, channel, connection_info])
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
