defmodule Otis.Startup do
  use GenServer

  def start_link(state, zones_supervisor, receivers_supervisor) do
    GenServer.start_link(__MODULE__, [state, zones_supervisor, receivers_supervisor], [])
  end

  def init([state, zones_supervisor, _receivers_supervisor]) do
    :ok = start_zones(state, zones_supervisor)
    Otis.State.Events.add_handler(Otis.LoggerHandler, :events)
    :ignore
  end

  defp start_zones(state, zones_supervisor) do
    {:ok, zones} = Otis.State.zones(state)
    start_zone(zones_supervisor, zones)
  end

  defp start_zone(zones_supervisor, [zone | rest] = _zones_to_start) do
    %Otis.State.Zone{ id: id, name: name } = zone
    Otis.Zones.start_zone(zones_supervisor, id, name)
    start_zone(zones_supervisor, rest)
  end

  defp start_zone(_zones_supervisor, []) do
    :ok
  end
end
