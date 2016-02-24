
defmodule Otis.State.Persistence.Zones do
  use     GenEvent
  require Logger

  alias Otis.State.Zone
  alias Otis.State.Repo

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:zone_added, id, %{name: name}}, state) do
    Repo.transaction fn ->
      Zone.find(id) |> add_zone(id, name)
    end
    {:ok, state}
  end
  def handle_event({:zone_removed, id}, state) do
    Repo.transaction fn ->
      Zone.find(id) |> remove_zone(id)
    end
    {:ok, state}
  end
  def handle_event({:zone_volume_change, id, volume}, state) do
    Repo.transaction fn ->
      id |> Zone.find |> volume_change(id, volume)
    end
    {:ok, state}
  end
  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp add_zone(nil, id, name) do
    zone = Zone.create!(id, name)
    Logger.info("Persisted zone #{ inspect zone }")
    zone
  end
  defp add_zone(zone, _id, _name) do
    Logger.debug "Existing zone #{ inspect zone }"
    zone
  end

  defp remove_zone(nil, id) do
    Logger.debug "Not removing non-existant zone #{ id }"
  end
  defp remove_zone(zone, _id) do
    Zone.delete!(zone)
  end

  defp volume_change(nil, id, _volume) do
    Logger.warn "Volume change for unknown zone #{ id }"
  end
  defp volume_change(zone, _id, volume) do
    Zone.volume(zone, volume)
  end
end
