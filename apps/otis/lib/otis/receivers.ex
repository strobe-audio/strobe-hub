defmodule Otis.Receivers do
  use     GenServer
  require Logger
  alias   Otis.Receiver
  alias   Otis.Receivers.DataConnection
  alias   Otis.Receivers.ControlConnection

  @name Otis.Receivers

  defmodule S do
    defstruct [receivers: nil]
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def receivers do
    receivers(@name)
  end

  def receivers(pid) do
    GenServer.call(pid, :receivers)
  end

  def receiver(id) do
    receiver(@name, id)
  end

  def receiver(pid, id) do
    GenServer.call(pid, {:receiver, id})
  end

  @doc "A useful wrapper command to set the volume for a given receiver id"
  def volume(id, volume)
  when is_binary(id) do
    volume = Otis.sanitize_volume(volume)
    case receiver(id) do
      {:ok, receiver} ->
        Otis.Receiver.volume receiver, volume
      _error ->
        Otis.State.Events.notify({:receiver_volume_change, [id, volume]})
    end
    {:ok, volume}
  end

  def attach(receiver_id, channel_id)
  when is_binary(receiver_id) and is_binary(channel_id) do
    attach(@name, receiver_id, channel_id)
  end

  def attach(pid, receiver_id, channel_id)
  when is_binary(receiver_id) and is_binary(channel_id) do
    GenServer.call(pid, {:attach, receiver_id, channel_id})
  end

  def connected?(id) do
    connected?(@name, id)
  end
  def connected?(pid, id) do
    GenServer.call(pid, {:is_connected, id})
  end

  defp config do
    Application.get_env :otis, __MODULE__
  end

  def data_port, do: config[:data_port]
  def ctrl_port, do: config[:ctrl_port]

  # At the receiver end:
  # {:ok, s} = Socket.TCP.connect "192.168.1.117", 5540, [mode: :active]
  # :gen_tcp.send s, "id:" <> Janis.receiver_id
  # :gen_tcp.close s
  def init([]) do
    Logger.info "Starting Receivers registry..."
    start_listener(@name.DataListener, data_port, DataConnection)
    start_listener(@name.ControlListener, ctrl_port, ControlConnection)
    Otis.Receivers.Database.attach(self())
    {:ok, %S{}}
  end

  defp start_listener(name, port, protocol) do
    :ranch.start_listener(name, 10, :ranch_tcp, [port: port], protocol, [supervisor: @name])
  end

  def handle_cast({:connect, type, id, {pid, socket}, params}, state) do
    state = connect(type, id, {pid, socket}, params, lookup(state, id), state)
    {:noreply, state}
  end

  def handle_cast({:disconnect, type, id}, state) do
    state = disconnect(type, id, lookup(state, id), state)
    {:noreply, state}
  end

  def handle_call(:receivers, _from, state) do
    {:reply, all(state), state}
  end

  def handle_call({:receiver, id}, _from, state) do
    {:reply, lookup(state, id), state}
  end

  def handle_call({:attach, receiver_id, channel_id}, _from, state) do
    receiver = case lookup(state, receiver_id) do
      {:ok, r} -> r
      _ -> nil
    end
    # In this case the event comes before the state change. Feels wrong but is
    # much simpler than any other way of moving receivers that I can think of
    Otis.State.Events.notify({:reattach_receiver, [receiver_id, channel_id, receiver]})
    {:reply, :ok, state}
  end

  def handle_call({:is_connected, id}, _from, state) do
    connected? = case lookup(state, id) do
      :error -> false
      {:ok, receiver} -> Receiver.alive?(receiver)
    end
    {:reply, connected?, state}
  end

  def handle_info({:'ETS-TRANSFER', table, _old_owner, _}, state) do
    {:noreply, %{state | receivers: table}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {id, receiver} = all(state) |> Receiver.matching_pid(pid)
    state = relatch(receiver, id, state)
    {:noreply, state}
  end

  defp insert(state, receiver) do
    insert(state, Receiver.id!(receiver), receiver)
  end
  defp insert(%S{receivers: nil}, _id, _receiver) do
    Logger.error("Receivers table nil!")
  end
  defp insert(%S{receivers: receivers} = state, id, receiver) do
    :ets.insert(receivers, {id, receiver})
    state
  end

  defp delete(%S{receivers: nil}, _receiver) do
    Logger.error("Receivers table nil!")
  end
  defp delete(%S{receivers: receivers} = state, receiver) do
    :ets.delete(receivers, receiver.id)
    state
  end

  defp lookup(%S{receivers: nil}, _id) do
    Logger.error("Receivers table nil!")
  end
  defp lookup(%S{receivers: receivers}, id) do
    case :ets.lookup(receivers, id) do
      [{^id, receiver}] -> {:ok, receiver}
      [] -> :error
    end
  end

  defp all(%{receivers: nil}) do
    Logger.error("Receivers table nil!")
  end
  defp all(%{receivers: receivers}) do
    :ets.foldl(fn(entry, list) -> [entry | list] end, [], receivers)
  end

  def connect(:ctrl, id, {pid, socket}, params, :error, state) do
    Receiver.new(id: id, ctrl: {pid, socket}, params: params) |> update_connect(id, state)
  end
  def connect(:ctrl, id, {pid, socket}, params, {:ok, receiver}, state) do
    Receiver.update(receiver, ctrl: {pid, socket}, params: params) |> update_connect(id, state)
  end

  def connect(:data, id, {pid, socket}, params, :error, state) do
    Receiver.new(id: id, data: {pid, socket}, params: params) |> update_connect(id, state)
  end
  def connect(:data, id, {pid, socket}, params, {:ok, receiver}, state) do
    Receiver.update(receiver, data: {pid, socket}, params: params) |> update_connect(id, state)
  end

  def disconnect(type, id, :error, _state) do
    Logger.warn "#{ inspect type } disconnect from unknown receiver #{ id }"
  end
  def disconnect(:data, id, {:ok, receiver}, state) do
    Receiver.update(receiver, data: nil) |> update_disconnect(id, state)
  end
  def disconnect(:ctrl, id, {:ok, receiver}, state) do
    Receiver.update(receiver, ctrl: nil) |> update_disconnect(id, state)
  end

  def relatch(receiver, id, state) do
    receiver = Receiver.create_latch(receiver)
    receiver
    |> update_receiver(id, state)
    |> after_relatch(receiver)
  end

  def update_connect(receiver, id, state) do
    update_receiver(receiver, id, state) |> after_connect(receiver)
  end

  def update_disconnect(receiver, id, state) do
    update_receiver(receiver, id, state) |> after_disconnect(receiver)
  end

  def update_receiver(receiver, state) do
    insert(state, receiver)
  end

  def update_receiver(receiver, id, state) do
    insert(state, id, receiver)
  end

  def after_connect(state, receiver) do
    start_valid_receiver(state, receiver, Receiver.alive?(receiver))
  end

  def after_disconnect(state, receiver) do
    state
    |> disable_zombie_receiver(receiver, Receiver.zombie?(receiver))
    |> remove_dead_receiver(receiver, Receiver.dead?(receiver))
  end

  # An unlatch event is our way of saying "reconnect this receiver" after some
  # configuration change (to move receiver between channels) so we just want to
  # invoke the same receiver assignment mechanism as used when a receive
  # connects
  def after_relatch(state, receiver) do
    state
    |> start_valid_receiver(receiver, Receiver.alive?(receiver))
  end

  def start_valid_receiver(state, receiver, true) do
    Otis.State.Events.notify({:receiver_connected, [receiver.id, receiver]})
    state
  end
  def start_valid_receiver(state, _receiver, false) do
    state
  end

  def disable_zombie_receiver(state, receiver, true) do
    Otis.State.Events.notify({:receiver_disconnected, [receiver.id, receiver]})
    state
  end
  def disable_zombie_receiver(state, _receiver, false) do
    state
  end

  def remove_dead_receiver(state, receiver, true) do
    Otis.State.Events.notify({:receiver_offline, [receiver.id, receiver]})
    delete(state, receiver)
  end
  def remove_dead_receiver(state, _receiver, false) do
    state
  end
end
