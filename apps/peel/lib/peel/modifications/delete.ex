defmodule Peel.Modifications.Delete do
  use GenStage

  alias Peel.Track
  alias Peel.Album
  alias Peel.Artist
  alias Peel.Repo

  require Logger

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: [{Peel.Webdav.Modifications, selector: &selector/1}]}
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

  def handle_event({:modification, {:delete, [path]} = evt}, state) do
    {:ok, _result} = Repo.transaction fn ->
      path |> Track.by_path |> delete_track(path) |> notify_deletion()
    end
    Peel.Webdav.Modifications.complete(evt)
    {:ok, state}
  end

  defp delete_track(nil, path)  do
    Logger.warn "Deleted file with no matching track #{path}"
  end

  defp delete_track(track, _path) do
    Track.delete(track) |> cleanup_album() |> cleanup_artist()
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

  if Code.ensure_compiled?(Otis.Events) do
    defp notify_deletion(nil), do: nil
    defp notify_deletion(track) do
      Otis.Events.notify({:source_deleted, [Otis.Library.Source.type(track), Otis.Library.Source.id(track)]})
    end
  else
    defp notify_deletion(_track), do: nil
  end
end
