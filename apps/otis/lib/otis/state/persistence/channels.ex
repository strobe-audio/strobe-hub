
defmodule Otis.State.Persistence.Channels do
  use     GenStage
  require Logger

  alias Otis.State.Channel
  alias Otis.State.Repo.Writer, as: Repo

  @config Application.get_env(:otis, Otis.State.Persistence, [])
  @volume_save_period Keyword.get(@config, :volume_save_period, 0)

  defmodule S do
    @moduledoc false
    defstruct [volumes: %{}, timer: nil]
  end

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, %S{}, subscribe_to: Otis.Events.producer}
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
  def handle_event({:channel_volume_change, [id, volume]}, %S{volumes: volumes, timer: timer} = state) do
    state = %S{ state | volumes: Map.put(volumes, id, volume), timer: start_timer(timer) }
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

  def handle_info(:save_volumes, %S{volumes: volumes} = state) do
    Repo.transaction fn ->
      Enum.each(volumes, fn({id, volume}) ->
        id |> Channel.find |> volume_change(id, volume)
        Otis.Events.notify({:"$__channel_volume_change", [id]})
      end)
    end
    {:noreply, [], %S{state | volumes: %{}, timer: nil}}
  end

  defp start_timer(nil) do
    Process.send_after(self(), :save_volumes, @volume_save_period)
  end
  defp start_timer(timer), do: timer

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
