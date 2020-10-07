defmodule Otis.State.Library do
  use GenStage
  use Strobe.Events.Handler

  require Logger

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, {}, subscribe_to: Strobe.Events.producer(&selector/1)}
  end

  defp selector({:library, _evt, _args}), do: true
  defp selector(_evt), do: false

  def handle_event({:library, :play, [channel_id, sources]}, state) do
    with {:ok, channel} <- Otis.Channels.find(channel_id) do
      Otis.Channel.append(channel, sources)
    else
      err -> Logger.error(err)
    end

    {:ok, state}
  end

  def handle_event(_evt, state) do
    {:ok, state}
  end
end
