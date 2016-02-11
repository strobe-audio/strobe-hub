defmodule Otis.Startup do
  use GenServer

  def start_link(state, zones_supervisor, receivers_supervisor) do
    GenServer.start_link(__MODULE__, [state, zones_supervisor, receivers_supervisor], [])
  end

  def init([state, zones_supervisor, _receivers_supervisor]) do
    :ok = state |> start_zones(zones_supervisor)
    Otis.State.Events.add_handler(Otis.LoggerHandler, :events)
    :ignore
  end

  defp start_zones(_state, zones_supervisor) do
    try do
      zones = Otis.State.Zone.all
      zones |> guarantee_zone |> start_zone(zones_supervisor)
    rescue
      Sqlite.Ecto.Error ->
        case Mix.env do
          :test -> nil
          _ ->
            Logger.error "Invalid db schema"
        end
      :ok
    end
  end

  defp guarantee_zone([]) do
    [Otis.State.Zone.create_default!]
  end
  defp guarantee_zone(zones) do
    zones
  end

  defp start_zone([zone | rest], zones_supervisor) do
    zones_supervisor.start(zone.id, zone.name)
    start_zone(rest, zones_supervisor)
  end

  defp start_zone([], _zones_supervisor) do
    :ok
  end
end
