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
  def start(%Otis.State.Zone{} = zone) do
    start(@registry_name, zone.id, zone)
  end
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
  when is_binary(id) do
    Otis.Zone.volume(find!(registry, id))
  end

  def volume(id, volume) when is_binary(id) do
    volume(@registry_name, id, volume)
  end
  def volume(registry, id, volume) do
    Otis.Zone.volume(find!(registry, id), volume)
  end

  def playing?(id) when is_binary(id) do
    playing?(@registry_name, id)
  end
  def playing?(registry, id) when is_binary(id) do
    Otis.Zone.playing?(find!(registry, id))
  end
  def play(id, playing) when is_binary(id) do
    play(@registry_name, id, playing)
  end
  def play(registry, id, playing) when is_binary(id) do
    Otis.Zone.play(find!(registry, id), playing)
  end

  def skip(id, source_id) when is_binary(id) do
    skip(@registry_name, id, source_id)
  end
  def skip(registry, id, source_id) do
    Otis.Zone.skip(find!(registry, id), source_id)
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
