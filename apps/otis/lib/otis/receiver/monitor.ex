defmodule Otis.Receiver.Monitor do
  use GenServer
  require Logger

  defmodule S do
    defstruct receiver: nil, receiver_node: nil, delta: 0, latency: 0, measurement_count: 0
  end

  def start_link(receiver, receiver_node) do
    GenServer.start_link(__MODULE__, [receiver, receiver_node])
  end

  def init([receiver, receiver_node])  do
    # Logger.disable self
    # Logger.debug "Starting monitor for #{receiver} node: #{inspect receiver_node}"
    # {:ok, collect_measurements(%S{receiver: receiver, receiver_node: receiver_node})}
    {:ok, {}}
  end
end

