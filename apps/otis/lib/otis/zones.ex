defmodule Otis.Zones do
  use GenServer

  alias Otis.Zone

  @registry_name Otis.Zones

  def start_link( name \\ @registry_name ) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def start_zone(id, name) do
    start_zone(@registry_name, id, name)
  end

  def start_zone(pid, id, name) do
    {:ok, zone} = response = Otis.Zones.Supervisor.start_zone(Otis.Zones.Supervisor, id, name)
    add(pid, zone)
    response
  end

  def add(zone) do
    add(@registry_name, zone)
  end

  def add(pid, zone) do
    GenServer.cast(pid, {:add, zone})
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

  def handle_call(:list, _from, zone_list) do
    zones = Enum.map zone_list, fn({_id, zone}) -> zone end
    {:reply, {:ok, zones}, zone_list}
  end

  def handle_call({:find, id}, _from, zone_list) do
    {:reply, find_by_id(zone_list, id), zone_list}
  end

  def handle_cast({:add, zone}, zone_list) do
    {:ok, id} = Zone.id(zone)
    {:noreply, [{id, zone} | zone_list]}
  end

  defp find_by_id(zone_list, id) do
    zone_list |>
    Enum.find(fn({zone_id, _zone}) -> zone_id == id end) |>
    zone_find_result
  end

  defp zone_find_result(nil) do
    :error
  end

  defp zone_find_result({_id, zone}) do
    {:ok, zone}
  end
end
