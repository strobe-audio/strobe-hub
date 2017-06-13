defmodule Otis.State.Persistence.Renditions do
  use     GenStage
  require Logger

  alias Otis.State.Rendition
  alias Otis.State.Repo.Writer, as: Repo

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: Otis.Events.producer}
  end

  def handle_events([], _from, state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:new_renditions, [_channel_id, renditions]}, state) do
    Repo.transaction fn ->
      Enum.each(renditions, fn(rendition) ->
        new_rendition(rendition)
      end)
    end
    {:ok, state}
  end
  def handle_event({:rendition_changed, [channel_id, old_rendition_id, _new_rendition_id]}, state) do
    Repo.transaction fn ->
      old_rendition_id |> load_rendition |> rendition_changed(old_rendition_id, channel_id)
    end
    Otis.Events.notify({:"$__rendition_changed", [channel_id]})
    {:ok, state}
  end
  def handle_event({:renditions_skipped, [channel_id, skipped_ids]}, state) do
    Repo.transaction fn ->
      skipped_ids |> Enum.map(&load_rendition/1) |> renditions_skipped(channel_id)
    end
    Otis.Events.notify({:"$__rendition_skip", [channel_id]})
    {:ok, state}
  end
  def handle_event({:rendition_deleted, [id, channel_id]}, state) do
    Repo.transaction fn ->
      [id] |> Enum.map(&load_rendition/1) |> compact_renditions() |> renditions_deleted(channel_id)
    end
    Otis.Events.notify({:"$__rendition_delete", [channel_id]})
    {:ok, state}
  end
  def handle_event({:rendition_progress, [_channel_id, _rendition_id, _position, :infinity]}, state) do
    {:ok, state}
  end
  def handle_event({:rendition_progress, [_channel_id, rendition_id, position, _duration]}, state) do
    :ok = Otis.State.RenditionProgress.update(rendition_id, position)
    Otis.Events.notify({:"$__rendition_progress", [rendition_id]})
    {:ok, state}
  end
  def handle_event({:source_deleted, [type, id]}, state) do
    renditions = Rendition.for_source(type, id)
    Enum.each(renditions, &Otis.Events.notify({:rendition_deleted, [&1.id, &1.channel_id]}))
    {:ok, state}
  end
  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp load_rendition(nil) do
    nil
  end
  defp load_rendition({id, _position, _source}) do
    load_rendition(id)
  end
  defp load_rendition(id) when is_binary(id) do
    Rendition.find(id)
  end

  defp new_rendition(rendition) do
    rendition
    |> Rendition.create!
    |> notify(:new_rendition_created)
  end

  # Happens when a channel starts playing
  defp rendition_changed(nil, nil, _channel_id) do
    nil
  end
  defp rendition_changed(nil, rendition_id, channel_id) do
    Logger.warn "Change of unknown rendition #{rendition_id} Channel:#{ channel_id }"
  end
  defp rendition_changed(rendition, rendition_id, channel_id) do
    rendition |> Rendition.played!(channel_id)
    notify(rendition_id, :old_rendition_removed)
  end

  defp renditions_skipped([], channel_id) do
    Rendition.renumber(channel_id)
  end
  defp renditions_skipped([nil | renditions], channel_id) do
    Logger.warn "Missing record for rendition channel:#{ channel_id }"
    renditions_skipped(renditions, channel_id)
  end

  defp renditions_skipped([rendition | renditions], channel_id) do
    rendition |> Rendition.delete!
    renditions_skipped(renditions, channel_id)
  end

  defp compact_renditions(renditions) do
    Enum.reject(renditions, &Kernel.is_nil/1)
  end

  defp renditions_deleted([], channel_id) do
    Rendition.renumber(channel_id)
  end
  defp renditions_deleted([rendition | renditions], channel_id) do
    rendition |> Rendition.delete!
    renditions_deleted(renditions, channel_id)
  end

  defp notify(rendition, event) do
    Otis.Events.notify({event, [rendition]})
    rendition
  end
end
