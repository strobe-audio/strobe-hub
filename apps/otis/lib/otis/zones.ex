defmodule Otis.Zones do
  use GenServer

  @registry_name Otis.Zones

  def start_link( name \\ @registry_name ) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def create(id, name) do
    create(@registry_name, id, name)
  end

  def create(registry, id, name) do
    add(:create, registry, id, %Otis.State.Zone{name: name})
  end

  @doc "Start an existing zone"
  def start(id, config) do
    start(@registry_name, id, config)
  end

  def start(registry, id, config) do
    add(:start, registry, id, config)
  end

  def destroy!(id) do
    destroy!(@registry_name, id)
  end

  def destroy!(registry, id) do
    {:ok, zone} = find(registry, id)
    response = Otis.Zones.Supervisor.stop_zone(zone)
    remove(registry, id)
    response
  end

  def list! do
    list!(@registry_name)
  end

  def list!(registry) do
    {:ok, zones} = list(registry)
    zones
  end

  def list do
    list(@registry_name)
  end

  def list(pid) do
    GenServer.call(pid, :list)
  end

  def find!(id) do
    find!(@registry_name, id)
  end
  def find!(registry, id) do
    {:ok, pid} = find(registry, id)
    pid
  end

  def find(id) do
    find(@registry_name, id)
  end

  def find(pid, id) do
    GenServer.call(pid, {:find, id})
  end

  def volume(%Otis.Zone{} = zone) do
    Otis.Zone.volume(zone)
  end
  def volume(id) do
    volume(@registry_name, id)
  end
  def volume(registry, id)
  when is_pid(registry) and is_binary(id) do
    Otis.Zone.volume(find!(registry, id))
  end

  defp add(action, registry, id, config) do
    {:ok, zone} = Otis.Zones.Supervisor.start_zone(id, config)
    add(action, registry, zone, id, config)
  end
  defp add(action, registry, zone, id, config) do
    GenServer.call(registry, {action, zone, id, config})
  end

  defp remove(pid, id) do
    GenServer.cast(pid, {:remove, id})
  end

  ############# Callbacks

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call(:list, _from, zone_list) do
    {:reply, {:ok, Map.values(zone_list)}, zone_list}
  end

  def handle_call({:find, id}, _from, zone_list) do
    {:reply, Map.fetch(zone_list, id), zone_list}
  end

  def handle_call({:create, zone, id, config}, _from, zone_list) do
    Otis.State.Events.notify({:zone_added, id, config})
    insert(zone_list, id, zone)
  end

  def handle_call({:start, zone, id, _config}, _from, zone_list) do
    insert(zone_list, id, zone)
  end

  def handle_cast({:remove, id}, zone_list) do
    Otis.State.Events.notify({:zone_removed, id})
    {:noreply, Map.delete(zone_list, id)}
  end

  defp insert(zone_list, id, zone) do
    {:reply, {:ok, zone}, Map.put(zone_list, id, zone)}
  end
end
