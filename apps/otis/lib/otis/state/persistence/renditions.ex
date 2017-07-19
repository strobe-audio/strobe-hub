defmodule Otis.State.Persistence.Renditions do
  use     GenStage
  use     Otis.Events.Handler
  require Logger

  alias Otis.State
  alias State.Rendition

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: Otis.Events.producer}
  end

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
    Enum.each(renditions, &Otis.Events.notify(:playlist, :remove, [&1.id, &1.channel_id]))
    {:ok, state}
  end

  def handle_event(_evt, state) do
    {:ok, state}
  end
end
