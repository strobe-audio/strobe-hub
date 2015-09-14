defmodule Otis.Resources do
  require Logger

  @name     Otis.Resources
  @interval 1000

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    Logger.debug "New Otis.Resources"
    Process.flag(:trap_exit, true)
    :resource_discovery.add_local_resource_tuple({:broadcaster, node()})
    :resource_discovery.add_target_resource_types([:receiver])
    :resource_discovery.add_callback_modules([@name])
    GenServer.cast(self, :discover_resources)
    {:ok, %{receivers: HashSet.new}}
  end

  def resource_up({:receiver, instance}) do
    GenServer.cast(@name, {:receiver_up, instance})
    :ok
  end

  def resource_up(_instance) do
    :ok
  end

  # defmodule Recon do
  #   # Could use something like this to share a cookie between the server
  #   # and the clients -- just send the cookie as part of the request
  #   # and response
  #   def request do
  #     :erlang.get_cookie |> Atom.to_string
  #   end
  #
  #   def response(_ip, _port, request) do
  #     :erlang.get_cookie |> Atom.to_string
  #   end
  #
  #   def handle_response(ip, port, response) do
  #     IO.inspect [:response, ip, port, response]
  #   end
  # end


  def handle_cast(:discover_resources, state) do
    {:noreply, discover_resources(state)}
  end

  def handle_cast({:receiver_up, id}, %{receivers: receivers} = state) do
    {:noreply, %{state | receivers: add_receiver(id, Set.member?(receivers, id), receivers)}}
  end

  def handle_info(:discover_resources, state) do
    {:noreply, discover_resources(state)}
  end

  def discover_resources(%{receivers: receivers} = state) do
    receivers = :reconnaissance.discover |> ping_resources(receivers)
    %{ state | receivers: receivers }
  end

  def ping_resources(resources, existing_receivers) do
    ping_resources(resources, existing_receivers, [])
  end

  def ping_resources([{_ip, _port, name} | t], receivers, new_receivers) do
    id = String.to_atom(name)
    case Set.member?(receivers, id) do
      true  -> ping_resources(t, receivers, new_receivers)
      false ->
        IO.inspect [:ping, name]
        :net_adm.ping id
        ping_resources(t, receivers, [id | new_receivers])
    end
  end

  def ping_resources([], existing_receivers, []) do
    existing_receivers
  end

  def ping_resources([], existing_receivers, _new_receivers) do
    :resource_discovery.trade_resources()
    existing_receivers
    # receivers = Enum.reduce new_receivers, existing_receivers, fn(r, e) -> Set.put e, r end
  end

  # def handle_info(:sync_resources, %{receivers: receivers} = state) do
  #   :resource_discovery.trade_resources()
  #   online = :resource_discovery.get_resources(:receiver)
  #             |> Enum.reduce HashSet.new, fn(r, s) -> Set.put(s, r) end
  #   IO.inspect [:sync_resources, online]
  #   Process.send_after(self, :sync_resources, @interval)
  #   {:noreply, %{state | receivers: monitor_receivers(receivers, online)}}
  # end

  # def monitor_receivers(receivers, online) do
  #   keep = Set.intersection(receivers, online)
  #   offline = Set.to_list Set.difference(receivers, online)
  #   # IO.inspect [:keep, keep, :offline, offline]
  #   remove_receivers(receivers, offline)
  # end

  def add_receiver(node_name, false = _is_member, receivers) do
    IO.inspect [:new_receiver_up, node_name]
    id = Otis.Receiver.id_from_node(node_name)
    Otis.Receivers.start_receiver(id, node_name)
    Set.put(receivers, id)
  end

  def add_receiver(_id, true = _is_member, receivers) do
    # TODO: don't discard receiver_up messages from receivers that we already
    # think are up. Instead replace the existing instance with the new one...
    receivers
  end

  def remove_receivers(receivers, [r | t]) do
    # TODO: tell the rest of the system that a receiver is gone
    remove_receivers(Set.delete(receivers, r), t)
  end

  def remove_receivers(receivers, []) do
    receivers
  end

  def terminate(_reason, _state) do
    IO.inspect [:resources, :terminate]
    # :resource_discovery.delete_local_resource_tuples(:resource_discovery.get_local_resource_tuples())
    # :resource_discovery.sync_resources()
    :ok
  end
end
