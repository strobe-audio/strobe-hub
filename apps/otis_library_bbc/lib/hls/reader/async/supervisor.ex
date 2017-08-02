defmodule HLS.Reader.Async.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_reader(reader, url, parent, id, deadline) do
    start_reader(__MODULE__, reader, url, parent, id, deadline)
  end

  def start_reader(supervisor, reader, url, parent, id, deadline) do
    {:ok, _pid} = Supervisor.start_child(supervisor, [reader, url, parent, id, deadline])
  end

  def init(:ok) do
    children = [
      worker(HLS.Reader.Async, [], [restart: :transient])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
