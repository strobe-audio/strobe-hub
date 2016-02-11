defmodule Otis.Receivers do
  use     GenServer
  use     Monotonic
  require Logger

  alias   Otis.Receiver

  @registry Otis.Receivers

  def start_link(name \\ @registry) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def start(id, zone, config, channel, connection_info) do
    start(@registry, id, zone, config, channel, connection_info)
  end

  def start(registry, id, zone, config, channel, connection_info) do
    Logger.info "Start receiver #{inspect id} #{inspect zone} #{inspect(connection_info)}"
    {:ok, pid} = response = Otis.Receivers.Supervisor.start_receiver(id, zone, config, channel, connection_info)
    add(registry, id, %Receiver{id: id, pid: pid})
    response
  end

  def stop(id) do
    stop(@registry, id)
  end
  def stop(registry, id) do
    GenServer.cast(registry, {:stop, id})
  end

  def add(id, receiver) do
    add(@registry, id, receiver)
  end

  def add(registry, id, receiver) do
    GenServer.call(registry, {:add, id, receiver})
  end

  def list! do
    list!(@registry)
  end

  def list!(registry) do
    {:ok, receivers} = list(registry)
    receivers
  end

  def list do
    list(@registry)
  end

  def list(pid) do
    GenServer.call(pid, :list)
  end

  def find!(id) do
    {:ok, pid} = find(id)
    pid
  end

  def find(id) do
    find(@registry, id)
  end

  def find(pid, id) do
    GenServer.call(pid, {:find, id})
  end

  def volume(pid, volume) when is_pid(pid) do
    Otis.Receiver.volume(pid, volume)
  end

  def volume(id, volume) do
    volume(find!(id), volume)
  end

  ############# Callbacks

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call(:list, _from, receivers) do
    {:reply, {:ok, Map.values(receivers)}, receivers}
  end

  def handle_call({:find, id}, _from, receivers) do
    {:reply, Map.fetch(receivers, id), receivers}
  end

  def handle_call({:add, id, receiver}, _from, receivers) do
    Otis.State.Events.notify({:receiver_started, id})
    {:reply, :ok, Map.put(receivers, id, receiver)}
  end

  def handle_cast({:stop, id}, receivers) do
    {receiver, receivers} = Map.pop(receivers, id)
    stop_receiver(receiver, id)
    {:noreply, receivers}
  end

  defp stop_receiver(nil, id) do
    Logger.warn "Attempt to stop unknown receiver #{ id }"
  end
  defp stop_receiver(receiver, _id) do
    Otis.Receiver.shutdown(receiver)
  end
end
