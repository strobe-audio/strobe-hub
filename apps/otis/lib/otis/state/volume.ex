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
    {:ok, old_multiplier} = Otis.Channels.volume(channel_id)
    {:ok, recevier_status, old_volume} = current_receiver_volume(id)
    new_multiplier = (old_multiplier * old_volume) / volume
    Otis.Channels.volume(channel_id, new_multiplier, lock: true)
    # Hack: offline receivers don't get the volume change through the above
    # command, so we have to issue the required event directly
    if recevier_status == :offline do
      Otis.Receivers.volume_event(id, volume)
    end
    {:ok, state}
  end

  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp current_receiver_volume(id) do
    case Otis.Receivers.volume(id) do
      {:ok, volume} ->
        {:ok, :online, volume}
      :error ->
        # Receiver is offline so go to db for value
        case Otis.State.Receiver.find(id) do
          %Otis.State.Receiver{volume: volume} ->
            {:ok, :offline, volume}
          _ ->
            {:error, :not_found}
        end
    end
  end

end
