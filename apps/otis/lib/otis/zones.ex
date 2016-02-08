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
    {:ok, zone} = response = Otis.Zones.Supervisor.start_zone(Otis.Zones.Supervisor, id, name)
    add(registry, zone, id, name)
    response
  end

  def remove_zone(id) do
    remove_zone(@registry_name, id)
  end

  def remove_zone(registry, id) do
    {:ok, zone} = find(registry, id)
    response = Otis.Zones.Supervisor.stop_zone(zone)
    remove(registry, id)
    response
  end

  def add(zone, id, name) do
    add(@registry_name, zone, id, name)
  end

  def add(pid, zone, id, name) do
    GenServer.cast(pid, {:add, zone, id, name})
  end

  def remove(id) do
    remove(@registry_name, id)
  end

  def remove(pid, id) do
    GenServer.cast(pid, {:remove, id})
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

  def handle_cast({:add, zone, id, name}, zone_list) do
    Otis.State.Events.notify({:zone_added, id, %{ name: name }})
    {:noreply, Map.put(zone_list, id, zone)}
  end

  def handle_cast({:remove, id}, zone_list) do
    Otis.State.Events.notify({:zone_removed, id})
    {:noreply, Map.delete(zone_list, id)}
  end
end
