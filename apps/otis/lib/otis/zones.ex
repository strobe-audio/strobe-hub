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
    add(:create, registry, id, name)
  end

  @doc "Start an existing zone"
  def start(id, name) do
    start(@registry_name, id, name)
  end

  def start(registry, id, name) do
    add(:start, registry, id, name)
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

  def find(id) do
    find(@registry_name, id)
  end

  def find(pid, id) do
    GenServer.call(pid, {:find, id})
  end


  defp add(action, registry, id, name) do
    {:ok, zone} = Otis.Zones.Supervisor.start_zone(Otis.Zones.Supervisor, id)
    add(action, registry, zone, id, name)
  end
  defp add(action, registry, zone, id, name) do
    GenServer.call(registry, {action, zone, id, name})
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

  def handle_call({:create, zone, id, name}, _from, zone_list) do
    Otis.State.Events.notify({:zone_added, id, %{ name: name }})
    insert(zone_list, id, zone)
  end

  def handle_call({:start, zone, id, name}, _from, zone_list) do
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
