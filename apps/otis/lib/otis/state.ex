defmodule Otis.State do
  use GenServer
  require Logger

  @name Otis.State

  defmodule S do
    defstruct zones: []
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  alias Otis.State.Zone

  def init(:ok) do
    Logger.info "Starting state..."
    zones = [
      %Zone{id: "office", name: "The Office", receiver_ids: [
          :"00-25-00-f4-1d-cd", # mac pro 5,1
          :"00-17-f2-09-20-9d", # mac pro 1,1
          :"b8-27-eb-f6-19-4b", # rpi 2 eth0
          :"e8-94-f6-24-4a-db", # rpi 2 wlan
          :"00-1c-42-fc-0d-b6"
        ]},
      %Zone{id: "downstairs", name: "Downstairs", receiver_ids: [
          :"00-00-00-00-00-00", # lo0
          :"e0-f8-47-42-aa-48",
          :"b8-27-eb-ce-43-c7",
          :"10-9a-dd-67-71-9c",
          :"2c-f0-ee-0a-e2-5e", # aines lappie
        ]}
    ]
    {:ok, %S{zones: zones}}
  end

  def zones do
    zones(@name)
  end

  def zones(pid) do
    GenServer.call(pid, :get_zones)
  end

  def restore_receiver(pid, id) do
    restore_receiver(@name, pid, id)
  end

  def restore_receiver(state, pid, id) do
    GenServer.cast(state, {:restore_receiver, pid, id})
  end

  def handle_call(:get_zones, _from, %S{zones: zones} = state) do
    {:reply, {:ok, zones}, state}
  end

  def handle_cast({:restore_receiver, pid, id}, %S{zones: zones} = state) do
    find_zone_for_receiver(zones, pid, id)
    {:noreply, state}
  end

  def find_zone_for_receiver([%Zone{id: zone_id, receiver_ids: receiver_ids} = _zone | zones], pid, id) do
    case Enum.find(receiver_ids, fn(rid) -> rid == id end) do
      nil -> find_zone_for_receiver(zones, pid, id)
      _   -> attach_receiver_to_zone(zone_id, pid)
    end
  end

  def find_zone_for_receiver([], _pid, id) do
    Logger.warn "No zone found for receiver #{id}"
  end

  def attach_receiver_to_zone(zone_id, receiver) do
    case Otis.Zones.find(zone_id) do
      {:ok, zone} ->
        Otis.Zone.add_receiver(zone, receiver)
      _ = msg ->
        Logger.warn "Error: #{inspect msg} :: Zone id #{zone_id} not found"
    end
  end
end
