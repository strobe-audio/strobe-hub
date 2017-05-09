defmodule Peel.Modifications.Move do
  use GenStage

  alias Peel.Track
  alias Peel.Repo

  require Logger

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: [{Peel.Webdav.Modifications, selector: &selector/1}]}
  end

  defp selector({:modification, {:move, _args}}), do: true
  defp selector(_evt), do: false

  def handle_events([], _from, state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:modification, {:move, [:file, src, dst]} = evt}, state) do
    {:ok, _result} = Repo.transaction fn ->
      src |> Track.by_path |> move_track(src, dst)
    end
    Peel.Webdav.Modifications.complete(evt)
    {:ok, state}
  end
  def handle_event({:modification, {:move, [:directory, src, dst]} = evt}, state) do
    {:ok, _result} = Repo.transaction fn ->
      src |> Track.under_root |> Enum.each(&move_directory(&1, src, dst))
    end
    Peel.Webdav.Modifications.complete(evt)
    {:ok, state}
  end

  defp move_track(nil, src, _dst) do
    Logger.warn "Move of path which has no corresponding Track '#{src}'"
  end
  defp move_track(track, _src, dst) do
    Track.move(track, dst)
  end

  defp move_directory(track, src, dst) do
    path = [dst, Path.relative_to(track.path, src)] |> Path.join
    Track.move(track, path)
  end
end
