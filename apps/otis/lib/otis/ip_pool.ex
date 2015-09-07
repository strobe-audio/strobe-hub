defmodule Otis.IPPool do
  use GenServer

  @name Otis.IPPool

  def start_link(network) do
    GenServer.start_link(__MODULE__, network, name: @name)
  end

  def init(network) do
    {:ok, {network, 0, 6666}}
  end

  def next_address do
    next_address(@name)
  end

  def next_address(pid) do
    GenServer.call(pid, :next_address)
  end

  def handle_call(:next_address, _from, {network, count, port} = state) do
    {a, b, c, _} = network
    n = count + 1
    address = {a, b, c, n}
    {:reply, {:ok, address, port}, {network, n, port}}
  end
end
