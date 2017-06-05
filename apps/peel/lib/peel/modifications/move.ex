defmodule Peel.Modifications.Move do
  use GenStage

  alias Peel.Collection
  alias Peel.Track
  alias Peel.Repo

  require Logger

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    IO.inspect [__MODULE__, :init, opts]
    {:consumer, opts, subscribe_to: [{Peel.Webdav.Modifications, selector: &selector/1}]}
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
    with {:ok, src_collection, src_track_path} <- Collection.from_path(src),
         {:ok, dst_collection, dst_track_path} <- Collection.from_path(dst)
    do
        {:ok, _result} = Repo.transaction fn ->
          src_track_path |> Track.by_path(src_collection) |> move_track(src, dst_collection, dst_track_path)
        end
        Peel.Webdav.Modifications.complete(evt)
    else
      _err ->
        Logger.warn "Cannot move file #{src} -> #{dst}"
    end
    {:ok, state}
  end
  def handle_event({:modification, {:move, [:directory, src, dst]} = evt}, state) do
    with {:ok, src_collection, src_dir_path} <- Collection.from_path(src),
         {:ok, dst_collection, dst_dir_path} <- Collection.from_path(dst)
    do
      {:ok, _result} = Repo.transaction fn ->
        src_dir_path
        |> Track.under_root(src_collection)
        |> Enum.each(&move_directory(&1, src_dir_path, dst_collection, dst_dir_path))
      end
      Peel.Webdav.Modifications.complete(evt)
    else
      {:error, :not_found} ->
        move_collection(evt)
      err ->
        IO.inspect [:move, err]
    end

    {:ok, state}
  end

  defp move_track(nil, src, _dst_collection, _dst_path) do
    Logger.warn "Move of path which has no corresponding Track '#{src}'"
  end
  defp move_track(track, _src, dst_collection, dst_path) do
    Track.move(track, dst_collection, dst_path)
  end

  defp move_directory(track, src, dst_collection, dst) do
    path = [dst, Path.relative_to(track.path, src)] |> Path.join
    Track.move(track, dst_collection, path)
  end

  defp move_collection({:move, [:directory, src, dst]} = evt) do
    with [src_name] <- Collection.split_path(src),
         [dst_name] <- Collection.split_path(dst),
         {:ok, collection} <- Collection.from_name(src_name),
         {:ok, _renamed} <- Collection.rename(collection, dst_name)
    do
      Peel.Webdav.Modifications.complete(evt)
    else
      err ->
        IO.inspect err
        Logger.warn "Cannot move collection #{src} -> #{dst}: #{inspect err}"
    end
  end
end
