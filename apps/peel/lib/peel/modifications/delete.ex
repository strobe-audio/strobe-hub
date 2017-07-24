defmodule Peel.Modifications.Delete do
  use GenStage

  alias Peel.{Album, Artist, Collection, Repo, Track}

  require Logger

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:consumer, opts, subscribe_to: [{Peel.WebDAV.Modifications, selector: &selector/1}]}
  end

  defp selector({:modification, {:delete, _args}}), do: true
  defp selector(_evt), do: false

  # In case of a delete
  # - Single file:
  #     find matching track & delete
  #
  # - Directory:
  #     find all matching tracks using wildcard & delete
  #
  # For each track deleted:
  #
  # - Record album
  # - Record artist
  #
  # For each affected album:
  #
  # - Check to see if it has any tracks
  # - If not delete the album
  #
  # For each affected artist:
  #
  # - See if artist has any tracks
  # - If not delete artist & all owned album-artist links
  def handle_events([], _from, state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:modification, {:delete, [:file, path]} = evt}, state) do
    case Collection.from_path(path) do
      {:ok, collection, track_path} ->
        {:ok, _result} = Repo.transaction fn ->
          track_path |> Track.by_path(collection) |> delete_track(collection, track_path)
        end
        Peel.WebDAV.Modifications.complete(evt)
      :error ->
        Logger.warn "Attempt to delete file in unknown collection #{inspect path}"
    end
    {:ok, state}
  end
  def handle_event({:modification, {:delete, [:directory, path]} = evt}, state) do
    case Collection.from_path(path) do
      # DELETE /Collection Path
      {:ok, collection, ""} ->
        Logger.info "Deleting collection #{collection.id} '#{collection.name}'"
        Collection.delete(collection)
        Peel.WebDAV.Modifications.complete(evt)
      {:ok, collection, root} ->
        {:ok, _result} = Repo.transaction fn ->
          root
          |> Track.under_root(collection)
          |> delete_tracks(collection, root)
        end
        Peel.WebDAV.Modifications.complete(evt)
      {:error, :not_found} ->
        Logger.warn "Attempt to delete file in unknown collection #{inspect path}"
    end
    {:ok, state}
  end
  def handle_event({:modification, {:delete, [_type, _path]}}, state) do
    {:ok, state}
  end

  defp delete_tracks([], _collection, _root) do
    nil
  end
  defp delete_tracks([track|tracks], collection, root) do
    track |> delete_track(collection, root)
    delete_tracks(tracks, collection, root)
  end

  defp delete_track(nil, collection, path)  do
    Logger.warn "Deleted file with no matching track collection: #{collection.id} #{inspect collection.name}: #{path}"
    nil
  end

  defp delete_track(track, _collection, _path) do
    Track.delete(track) |> cleanup_album() |> cleanup_artist() |> notify_deletion()
  end

  defp cleanup_album(track) do
    album = Track.album(track)
    case Album.tracks(album) do
      [] ->
        Album.delete(album)
      _ ->
        nil
    end
    track
  end

  defp cleanup_artist(track) do
    artist = Track.artist(track)
    case Artist.tracks(artist) do
      [] ->
        Artist.delete(artist)
      _ ->
        nil
    end
    track
  end

  defp notify_deletion(nil), do: nil
  defp notify_deletion(track) do
    Strobe.Events.notify(:rendition, :source_delete, [Otis.Library.Source.type(track), Otis.Library.Source.id(track)])
  end
end
