defmodule Peel.Modifications.Create do
  use     GenStage
  require Logger

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: [{Peel.Webdav.Modifications, selector: &selector/1}]}
  end

  defp selector({:modification, {:create, _args}}), do: true
  defp selector(_evt), do: false

  def handle_events([], _from, state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:modification, {:create, [path]} = evt}, state) do
    case Peel.Importer.track(path) do
      {:existing, _track} ->
        nil
      {:created, track} ->
        Logger.info "Added track #{ track.id } #{ track.performer } > #{ track.album_title } > #{ inspect track.title }"
    end
    Peel.Webdav.Modifications.complete(evt)
    {:ok, state}
  end
end
