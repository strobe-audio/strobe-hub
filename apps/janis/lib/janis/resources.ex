defmodule Janis.Resources do
  @name Janis.Resources

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    Process.flag(:trap_exit, true)
    :resource_discovery.add_local_resource_tuple({:receiver, node()})
    :resource_discovery.add_target_resource_types([:broadcaster])
    GenServer.cast(self, :discover_resources)
    {:ok, %{}}
  end

  def handle_cast(:discover_resources, state) do
    IO.inspect [:discvoer_resources]
    :reconnaissance.discover |> ping_resources
    {:noreply, state}
  end

  def ping_resources([{_ip, _port, name} | t]) do
    case :net_adm.ping String.to_atom(name) do
      :pong -> true
        IO.inspect [:pong, name]
      :pang -> false
        IO.inspect [:pang, name]
    end
    ping_resources(t)
  end

  def ping_resources([]) do
    IO.inspect [:trading_resources]
    :resource_discovery.trade_resources()
  end

  def terminate(_reason, _state) do
    IO.inspect [:terminate]
    :resource_discovery.delete_local_resource_tuples(:resource_discovery.get_local_resource_tuples())
    :resource_discovery.trade_resources()
    :ok
  end
end
