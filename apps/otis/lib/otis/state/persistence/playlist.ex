defmodule Otis.State.Persistence.Playlist do
  use GenStage
  use Strobe.Events.Handler
  require Logger

  alias Otis.State
  alias State.Playlist
  alias State.Repo.Writer, as: Repo

  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: Strobe.Events.producer(&selector/1)}
  end

  defp selector({:playlist, _evt, _args}), do: true
  defp selector(_evt), do: false

  def handle_event({:playlist, :append, [channel_id, renditions]}, state) do
    channel = channel(channel_id)

    {:ok, {_channel, inserted}} =
      Repo.transaction(fn ->
        Playlist.append!(channel, renditions)
      end)

    Enum.each(inserted, &new_rendition/1)
    {:ok, state}
  end

  def handle_event(
        {:playlist, :advance, [channel_id, _old_rendition_id, new_rendition_id]},
        state
      ) do
    {:ok, {_channel, skipped}} =
      Repo.transaction(fn ->
        rendition_change(channel_id, new_rendition_id)
      end)

    Enum.each(skipped, &Strobe.Events.notify(:rendition, :played, [&1.id]))
    {:ok, state}
  end

  def handle_event({:playlist, :skip, [channel_id, skip_id, skipped_ids]}, state) do
    {:ok, {_channel, deleted}} =
      Repo.transaction(fn ->
        skipped_ids |> renditions_skipped(channel_id, skip_id)
      end)

    Enum.each(deleted, &Strobe.Events.notify(:rendition, :skip, [channel_id, &1.id]))
    {:ok, state}
  end

  def handle_event({:playlist, :remove, [id, channel_id]}, state) do
    channel = channel(channel_id)

    {:ok, {_channel, removed}} =
      Repo.transaction(fn ->
        Playlist.delete!(channel, id, 1)
      end)

    Enum.each(removed, &Strobe.Events.notify(:rendition, :delete, [&1.id, channel_id]))
    {:ok, state}
  end

  def handle_event({:playlist, :clear, [channel_id, active_rendition_id]}, state) do
    {:ok, {_channel, deleted}} =
      Repo.transaction(fn ->
        channel_id |> channel() |> Playlist.clear!(active_rendition_id)
      end)

    Enum.each(deleted, &Strobe.Events.notify(:rendition, :delete, [&1.id, channel_id]))
    {:ok, state}
  end

  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp new_rendition(rendition) do
    Strobe.Events.notify(:rendition, :create, [rendition])
  end

  defp rendition_change(channel_id, current_rendition_id) do
    channel_id |> channel() |> Playlist.advance!(current_rendition_id)
  end

  defp renditions_skipped(_renditions, channel_id, skip_id) do
    channel_id |> channel() |> Playlist.advance!(skip_id)
  end

  defp channel(id) do
    State.Channel.find!(id)
  end
end
