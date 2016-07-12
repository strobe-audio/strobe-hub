defmodule HLS.DataStream.Supervisor do
  use Supervisor

  @supervisor __MODULE__

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: @supervisor)
  end

  def start(%HLS.Stream{} = stream, opts) do
    Supervisor.start_child(@supervisor, [stream, opts])
  end

  def stop(pid) do
    Supervisor.terminate_child(@supervisor, pid)
  end

  def init(_opts) do
    children = [
      worker(HLS.DataStream, [], [restart: :transient])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end

