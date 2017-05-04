
defmodule Otis.State.Persistence.Channels do
  use     GenStage
  require Logger

  alias Otis.State.Channel
  alias Otis.State.Repo

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: Otis.Events.producer}
  end

  def handle_events([], _from,state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:channel_added, [id, %{name: name}]}, state) do
    Repo.transaction fn ->
      Channel.find(id) |> add_channel(id, name)
    end
    {:ok, state}
  end
  def handle_event({:channel_removed, [id]}, state) do
    Repo.transaction fn ->
      Channel.find(id) |> remove_channel(id)
    end
    Otis.Events.notify({:"$__channel_remove", [id]})
    {:ok, state}
  end
  def handle_event({:channel_volume_change, [id, volume]}, state) do
    Repo.transaction fn ->
      id |> Channel.find |> volume_change(id, volume)
    end
    Otis.Events.notify({:"$__channel_volume_change", [id]})
    {:ok, state}
  end
  def handle_event({:channel_rename, [id, name]}, state) do
    Repo.transaction fn ->
      id |> Channel.find |> rename(id, name)
    end
    Otis.Events.notify({:"$__channel_rename", [id]})
    {:ok, state}
  end
  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp add_channel(nil, id, name) do
    channel = Channel.create!(id, name)
    Logger.info("Persisted channel #{ inspect channel }")
    channel
  end
  defp add_channel(channel, _id, _name) do
    Logger.debug "Existing channel #{ inspect channel }"
    channel
  end

  defp remove_channel(nil, id) do
    Logger.debug "Not removing non-existant channel #{ id }"
  end
  defp remove_channel(channel, _id) do
    Channel.delete!(channel)
  end

  defp volume_change(nil, id, _volume) do
    Logger.warn "Volume change for unknown channel #{ id }"
  end
  defp volume_change(channel, _id, volume) do
    Channel.volume(channel, volume)
  end

  defp rename(nil, id, _name) do
    Logger.warn "Rename of unknown channel #{ id }"
  end
  defp rename(channel, _id, name) do
    Channel.rename(channel, name)
  end
end
