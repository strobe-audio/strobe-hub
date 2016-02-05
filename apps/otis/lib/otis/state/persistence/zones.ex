
defmodule Otis.State.Persistence.Zones do
  use     GenEvent
  import  Ecto.Query
  require Logger

  alias Otis.State.Zone

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:zone_added, id, %{name: name}}, state) do
    Zone.find(id) |> add_zone(id, name)
    {:ok, state}
  end
  def handle_event({:zone_removed, id}, state) do
    Zone.find(id) |> remove_zone(id)
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
end
