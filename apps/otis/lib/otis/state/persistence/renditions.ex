defmodule Otis.State.Persistence.Renditions do
  use     GenStage
  require Logger

  alias Otis.State
  alias State.Rendition
  alias State.Playlist
  alias State.Repo.Writer, as: Repo

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

  def handle_event({:append_renditions, [channel_id, renditions]}, state) do
    channel = channel(channel_id)
    {:ok, {_channel, inserted}} = Repo.transaction fn ->
      Playlist.append!(channel, renditions)
    end
    Enum.each(inserted, &new_rendition/1)
    Otis.Events.notify({:"$__append_renditions", [channel_id]})
    {:ok, state}
  end

  def handle_event({:rendition_changed, [channel_id, _old_rendition_id, new_rendition_id]}, state) do
    {:ok, {_channel, skipped}} = Repo.transaction fn ->
      rendition_change(channel_id, new_rendition_id)
    end
    Enum.each(skipped, &notify(&1.id, :rendition_played))
    Otis.Events.notify({:"$__rendition_changed", [channel_id]})
    {:ok, state}
  end

  def handle_event({:renditions_skipped, [channel_id, skip_id, skipped_ids]}, state) do
    {:ok, {_channel, deleted}} = Repo.transaction fn ->
      skipped_ids |> Enum.map(&load_rendition/1) |> renditions_skipped(channel_id, skip_id)
    end
    Enum.each(deleted, &Otis.Events.notify({:rendition_deleted, [&1.id, channel_id]}))
    Otis.Events.notify({:"$__rendition_skip", [channel_id]})
    {:ok, state}
  end

  def handle_event({:rendition_deleted, [_id, _channel_id]}, state) do
    {:ok, state}
  end

  def handle_event({:rendition_remove, [id, channel_id]}, state) do
    channel = channel(channel_id)
    {:ok, {_channel, removed}} =
      Repo.transaction fn ->
        Playlist.delete!(channel, id, 1)
      end
    Enum.each(removed, &Otis.Events.notify({:rendition_deleted, [&1.id, channel_id]}))
    Otis.Events.notify({:"$__rendition_remove", [channel_id]})
    {:ok, state}
  end

  def handle_event({:playlist_cleared, [channel_id, active_rendition_id]}, state) do
    {:ok, {_channel, deleted}} = Repo.transaction fn ->
      channel_id |> channel() |> Playlist.clear!(active_rendition_id)
    end
    Enum.each(deleted, &Otis.Events.notify({:rendition_deleted, [&1.id, channel_id]}))
    Otis.Events.notify({:"$__playlist_cleared", [channel_id, active_rendition_id]})
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
    Enum.each(renditions, &Otis.Events.notify({:rendition_remove, [&1.id, &1.channel_id]}))
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
    rendition |> notify(:new_rendition_created)
  end

  defp rendition_change(channel_id, current_rendition_id) do
    channel_id |> channel() |> Playlist.advance!(current_rendition_id)
  end

  defp renditions_skipped([], channel_id, _skip_id) do
    {channel(channel_id), []}
  end
  defp renditions_skipped([nil | rest], channel_id, skip_id) do
    renditions_skipped(rest, channel_id, skip_id)
  end
  defp renditions_skipped([first | _] = renditions, channel_id, _skip_id) do
    channel = channel(channel_id)
    Playlist.delete!(channel, first.id, length(renditions))
  end

  defp notify(rendition, event) do
    Otis.Events.notify({event, [rendition]})
    rendition
  end

  defp channel(id) do
    State.Channel.find!(id)
  end
end
