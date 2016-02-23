defmodule Otis.State.Persistence.Sources do
  use     GenEvent
  require Logger

  alias Otis.State.Source

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:new_source, zone_id, position, source}, state) do
    source |> load_source |> new_source(zone_id, position, source)
    {:ok, state}
  end
  def handle_event({:source_changed, zone_id, old_source_id, _new_source_id}, state) do
    old_source_id |> load_source |> source_changed(old_source_id, zone_id)
    {:ok, state}
  end
  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp load_source(nil) do
    nil
  end
  defp load_source({id, _source}) do
    load_source(id)
  end
  defp load_source(id) when is_binary(id) do
    Source.find(id)
  end

  defp new_source(nil, zone_id, position, {id, source}) do
    %Source{
      id: id,
      position: position,
      zone_id: zone_id,
      source_id: source_id(source),
      source_type: source_type(source),
    }
    |> Source.create!
    |> notify(:new_source_created)
  end
  defp new_source(_record, zone_id, _position, {id, _source}) do
    Logger.warn "Adding source with duplicate id #{id} zone:#{zone_id}"
  end

  defp source_changed(nil, source_id, zone_id) do
    Logger.warn "Change of unknown source #{source_id} Zone:#{ zone_id }"
  end
  defp source_changed(source, source_id, _zone_id) do
    source |> Source.delete!
    notify(source_id, :old_source_removed)
  end

  defp source_type(source) do
    Otis.Source.type(source) |> to_string
  end

  defp source_id(source) do
    Otis.Source.id(source)
  end

  defp notify(source, event) do
    Otis.State.Events.notify({event, source})
    source
  end
end
