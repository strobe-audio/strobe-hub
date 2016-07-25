defmodule HLS.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], [])
  end

  def init(_opts) do
    children = [
      supervisor(HLS.Client.Supervisor, []),
      supervisor(HLS.Reader.Async.Supervisor, []),
    ]
    supervise(children, strategy: :one_for_one)
  end
end
