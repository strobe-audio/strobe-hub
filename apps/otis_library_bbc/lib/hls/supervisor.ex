defmodule HLS.Supervisor do
  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, [], [])
  end

  def init(_opts) do
    children = [
      HLS.Client.Supervisor,
      HLS.Reader.Async.Supervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
