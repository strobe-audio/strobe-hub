defmodule Otis.State.Persistence.Renditions do
  use     GenStage
  use     Strobe.Events.Handler
  require Logger

  alias Otis.State
  alias State.Rendition

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: Strobe.Events.producer(&selector/1)}
  end

  defp selector({:rendition, _evt, _args}), do: true
  defp selector(_evt), do: false

  def handle_event({:rendition, :delete, [_id, _channel_id]}, state) do
    {:ok, state}
  end

  def handle_event({:rendition, :progress, [_channel_id, _rendition_id, _position, :infinity]}, state) do
    {:ok, state}
  end

  def handle_event({:rendition, :progress, [_channel_id, rendition_id, position, _duration]}, state) do
    :ok = Otis.State.RenditionProgress.update(rendition_id, position)
    {:ok, state}
  end

  def handle_event({:rendition, :source_delete, [type, id]}, state) do
    renditions = Rendition.for_source(type, id)
    Enum.each(renditions, &Strobe.Events.notify(:playlist, :remove, [&1.id, &1.channel_id]))
    {:ok, state}
  end

  def handle_event(_evt, state) do
    {:ok, state}
  end
end
