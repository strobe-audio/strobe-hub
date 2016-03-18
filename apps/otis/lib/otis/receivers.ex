defmodule Otis.Receivers do
  use     GenServer
  require Logger
  alias   Otis.Receiver
  alias   Otis.Receivers.DataConnection
  alias   Otis.Receivers.ControlConnection

  @name Otis.Receivers

  defmodule S do
    defstruct [receivers: %{}]
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
    {:ok, receiver} = receiver(id)
    Otis.Receiver.volume receiver, volume
    {:ok, receiver}
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
    {:ok, _data_pid} = start_listener(@name.DataListener, data_port, DataConnection)
    {:ok, _ctrl_pid} = start_listener(@name.ControlListener, ctrl_port, ControlConnection)
    {:ok, %S{}}
  end

  defp start_listener(name, port, protocol) do
    :ranch.start_listener(name, 10, :ranch_tcp, [port: port], protocol, [supervisor: @name])
  end

  def handle_cast({:connect, type, id, {pid, socket}, params}, state) do
    state = connect(type, id, {pid, socket}, params, Map.get(state.receivers, id), state)
    {:noreply, state}
  end

  def handle_cast({:disconnect, type, id}, state) do
    state = disconnect(type, id, Map.get(state.receivers, id), state)
    {:noreply, state}
  end

  def handle_call(:receivers, _from, %S{receivers: receivers} = state) do
    {:reply, Map.values(receivers), state}
  end

  def handle_call({:receiver, id}, _from, %S{receivers: receivers} = state) do
    {:reply, Map.fetch(receivers, id), state}
  end

  def connect(:ctrl, id, {pid, socket}, params, nil, state) do
    Receiver.new(id: id, ctrl: {pid, socket}, params: params) |> update_connect(id, state)
  end
  def connect(:ctrl, id, {pid, socket}, params, receiver, state) do
    Receiver.update(receiver, ctrl: {pid, socket}, params: params) |> update_connect(id, state)
  end

  def connect(:data, id, {pid, socket}, params, nil, state) do
    Receiver.new(id: id, data: {pid, socket}, params: params) |> update_connect(id, state)
  end
  def connect(:data, id, {pid, socket}, params, receiver, state) do
    Receiver.update(receiver, data: {pid, socket}, params: params) |> update_connect(id, state)
  end

  def disconnect(type, id, nil, _state) do
    Logger.warn "#{ inspect type } disconnect from unknown receiver #{ id }"
  end
  def disconnect(:data, id, receiver, state) do
    Receiver.update(receiver, data: nil) |> update_disconnect(id, state)
  end
  def disconnect(:ctrl, id, receiver, state) do
    Receiver.update(receiver, ctrl: nil) |> update_disconnect(id, state)
  end

  def update_connect(receiver, id, state) do
    update_receiver(receiver, id, state) |> after_connect(receiver)
  end

  def update_disconnect(receiver, id, state) do
    update_receiver(receiver, id, state) |> after_disconnect(receiver)
  end

  def update_receiver(receiver, id, state) do
    %{ state | receivers: Map.put(state.receivers, id, receiver)}
  end

  def after_connect(state, receiver) do
    start_valid_receiver(state, receiver, Receiver.alive?(receiver))
  end

  def after_disconnect(state, receiver) do
    state
    |> disable_zombie_receiver(receiver, Receiver.zombie?(receiver))
    |> remove_dead_receiver(receiver, Receiver.dead?(receiver))
  end

  def start_valid_receiver(state, receiver, true) do
    Otis.State.Events.notify({:receiver_connected, receiver.id, receiver})
    state
  end
  def start_valid_receiver(state, _receiver, false) do
    state
  end

  def disable_zombie_receiver(state, receiver, true) do
    Otis.State.Events.notify({:receiver_disconnected, receiver.id, receiver})
    state
  end
  def disable_zombie_receiver(state, _receiver, false) do
    state
  end

  def remove_dead_receiver(state, receiver, true) do
    Otis.State.Events.notify({:receiver_offline, receiver.id, receiver})
    %{state | receivers: Map.delete(state.receivers, receiver.id)}
  end
  def remove_dead_receiver(state, _receiver, false) do
    state
  end
end
