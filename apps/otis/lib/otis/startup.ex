defmodule Otis.Startup do
  use     GenServer
  require Logger

  def start_link(state \\ Otis.State, zones_supervisor \\ Otis.Zones)
  def start_link(state, zones_supervisor) do
    GenServer.start_link(__MODULE__, [state, zones_supervisor], [])
  end

  def init([state, zones_supervisor]) do
    :ok = state |> start_zones(zones_supervisor)
    :ok = state |> restore_source_lists(zones_supervisor)
    Otis.State.Events.add_handler(Otis.LoggerHandler, :events)
    :ignore
  end

  def start_zones(_state, zones_supervisor) do
    ignoring_errors_in_tests fn ->
      zones = Otis.State.Zone.all
      zones |> guarantee_zone |> start_zone(zones_supervisor)
    end
  end

  defp guarantee_zone([]) do
    [Otis.State.Zone.create_default!]
  end
  defp guarantee_zone(zones) do
    zones
  end

  defp start_zone([zone | rest], zones_supervisor) do
    Logger.info "===> Starting zone #{ zone.id } #{ inspect zone.name }"
    Otis.Zones.start(zones_supervisor, zone.id, zone)
    start_zone(rest, zones_supervisor)
  end

  defp start_zone([], _zones_supervisor) do
    :ok
  end

  def restore_source_lists(_state, zones_supervisor) do
    ignoring_errors_in_tests fn ->
      {:ok, zones} = Otis.Zones.list(zones_supervisor)
      zones |> restore_source_list
    end
  end
  defp restore_source_list([]) do
    :ok
  end
  defp restore_source_list([zone | zones]) do
    {:ok, zone_id} = Otis.Zone.id(zone)
    {:ok, source_list} = Otis.Zone.source_list(zone)
    sources = Otis.State.Source.restore(zone_id)
    Otis.SourceList.replace(source_list, sources)
    restore_source_list(zones)
  end

  # We're not guaranteed to have a valid db schema when running in test mode
  # so just ignore those errors here (assuming that anything less transitory
  # will be caught by the tests themselves)
  defp ignoring_errors_in_tests(action) do
    try do
      action.()
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
end
