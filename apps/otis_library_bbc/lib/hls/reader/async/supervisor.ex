defmodule HLS.Reader.Async.Supervisor do
  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def start_reader(reader, url, parent, id, deadline) do
    start_reader(__MODULE__, reader, url, parent, id, deadline)
  end

  def start_reader(supervisor, reader, url, parent, id, deadline) do
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        supervisor,
        {HLS.Reader.Async, [reader, url, parent, id, deadline]}
      )
  end

  def init(:ok) do
    children = [
      # worker(HLS.Reader.Async, [], restart: :transient)
      {DynamicSupervisor, strategy: :one_for_one, name: __MODULE__}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
