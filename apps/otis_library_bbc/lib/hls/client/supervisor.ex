defmodule HLS.Client.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def start(%HLS.Stream{} = stream, id, opts) do
    DynamicSupervisor.start_child(__MODULE__, {HLS.Client, [stream, id, opts]})
  end

  def stop(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end

  def init(_opts) do
    children = [
      # worker(HLS.Client, [], restart: :transient)
      {DynamicSupervisor, strategy: :one_for_one, name: __MODULE__}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
