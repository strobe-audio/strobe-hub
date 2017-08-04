defmodule Otis.State.Volume do
  use     GenStage
  use     Strobe.Events.Handler

  require Logger

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, {}, subscribe_to: Strobe.Events.producer(&selector/1)}
  end

  defp selector({:volume, _evt, _args}), do: true
  defp selector(_evt), do: false

  def handle_event({:volume, :lock, [:receiver, channel_id, id, volume]}, state) do
    {:ok, old_volume} = Otis.Receivers.volume(id)
    {:ok, old_multiplier} = Otis.Channels.volume(channel_id)
    new_multiplier = (old_multiplier * old_volume) / volume
    Otis.Channels.volume(channel_id, new_multiplier, lock: true)
    {:ok, state}
  end

  def handle_event(_evt, state) do
    {:ok, state}
  end
end
