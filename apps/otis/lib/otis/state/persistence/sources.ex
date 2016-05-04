defmodule Otis.State.Persistence.Sources do
  use     GenEvent
  require Logger

  alias Otis.State.Source
  alias Otis.State.Repo

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:new_source, channel_id, position, source}, state) do
    Repo.transaction fn ->
      source |> load_source |> new_source(channel_id, position, source)
    end
    {:ok, state}
  end
  def handle_event({:source_changed, channel_id, old_source_id, _new_source_id}, state) do
    Repo.transaction fn ->
      old_source_id |> load_source |> source_changed(old_source_id, channel_id)
    end
    {:ok, state}
  end
  def handle_event({:sources_skipped, channel_id, skipped_ids}, state) do
    Repo.transaction fn ->
      skipped_ids |> Enum.map(&load_source/1) |> sources_skipped(channel_id)
    end
    {:ok, state}
  end
  def handle_event({:source_progress, _channel_id, source_id, position, _duration}, state) do
    Repo.transaction fn ->
      source_id |> load_source |> source_progress(source_id, position)
    end
    {:ok, state}
  end
  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp load_source(nil) do
    nil
  end
  defp load_source({id, _position, _source}) do
    load_source(id)
  end
  defp load_source(id) when is_binary(id) do
    Source.find(id)
  end

  defp new_source(nil, channel_id, position, {id, playback_position, source}) do
    %Source{
      id: id,
      position: position,
      playback_position: playback_position,
      channel_id: channel_id,
      source_id: source_id(source),
      source_type: source_type(source),
    }
    |> Source.create!
    |> notify(:new_source_created)
  end
  defp new_source(_record, channel_id, _position, {id, _source}) do
    Logger.warn "Adding source with duplicate id #{id} channel:#{channel_id}"
  end

  # Happens when a channel starts playing
  defp source_changed(nil, nil, _channel_id) do
    nil
  end
  defp source_changed(nil, source_id, channel_id) do
    Logger.warn "Change of unknown source #{source_id} Channel:#{ channel_id }"
  end
  defp source_changed(source, source_id, channel_id) do
    source |> Source.played!(channel_id)
    notify(source_id, :old_source_removed)
  end

  defp sources_skipped([], channel_id) do
    Source.renumber(channel_id)
  end
  defp sources_skipped([nil | sources], channel_id) do
    Logger.warn "Missing record for source channel:#{ channel_id }"
    sources_skipped(sources, channel_id)
  end
  defp sources_skipped([source | sources], channel_id) do
    source |> Source.delete!
    sources_skipped(sources, channel_id)
  end

  defp source_progress(nil, id, position) do
    Logger.warn "Progress event for unknown source #{ inspect id } (#{ position })"
    nil
  end
  defp source_progress(source, _id, position) do
    Source.playback_position(source, position)
  end

  defp source_type(source) do
    source |> Otis.Source.type |> to_string
  end

  defp source_id(source) do
    Otis.Source.id(source)
  end

  defp notify(source, event) do
    Otis.State.Events.notify({event, source})
    source
  end
end
