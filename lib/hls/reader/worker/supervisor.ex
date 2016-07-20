defmodule HLS.Reader.Worker.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_reader(mode, reader, url, parent, id) do
    start_reader(__MODULE__, mode, reader, url, parent, id)
  end

  def start_reader(supervisor, mode, reader, url, parent, id) do
		{:ok, _pid} = Supervisor.start_child(supervisor, [mode, reader, url, parent, id])
  end

  def init(:ok) do
    children = [
      worker(HLS.Reader.Worker, [], [restart: :transient])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
