defmodule HLS.Client.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start(%HLS.Stream{} = stream, opts) do
    Supervisor.start_child(__MODULE__, [stream, opts])
  end

  def stop(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end

  def init(_opts) do
    children = [
      worker(HLS.Client, [], [restart: :transient])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end


