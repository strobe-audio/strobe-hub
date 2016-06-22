defmodule Peel.Scanner do
  require Logger

  alias   Peel.Track

  def start(path) do
    path |> stream |> Enum.each(&scan/1) |> scan_complete
  end

  def stream(path) do
    path
    |> List.wrap
    |> Peel.DirWalker.stream
    |> Stream.filter(&filetype_filter/1)
  end

  def scan(path) do
    Peel.Repo.transaction fn ->
      path |> Peel.Track.by_path |> track(path, true)
    end
    path
  end

  def scan_complete(path) do
    Otis.State.Events.notify({:scan_finished, path})
  end

  def track(nil, path, notify) do
    create_track(path, metadata(path), notify)
  end
  def track(%Peel.Track{} = track, _path, _notify) do
    # Exists - TODO: should check mtime for modifications and act...
    track
  end

  def create_track(path, path_metadata, notify \\ false) do
    path
    |> Track.new(clean_metadata(path_metadata))
    |> Track.create!
    |> log_track_creation(notify)
  end

  def metadata(path) do
    path
    |> Otis.Source.File.metadata!
  end

  def clean_metadata(metadata) do
    metadata
    |> Map.from_struct
    # Reject any nil values so that they don't overwrite defaults
    |> Enum.reject(fn({_, v}) -> is_nil(v) end)
    |> Enum.map(&translate_metadata_key/1)
  end

  def log_track_creation(track, false) do
    track
  end

  def log_track_creation(track, true) do
    Logger.info "Added track #{ track.id } #{ track.performer } > #{ track.album_title } > #{ inspect track.title }"
    track
  end

  # We reserve %Track.album to point to the album relation
  def translate_metadata_key({:album, album}), do: {:album_title, album}
  def translate_metadata_key(term), do: term

  def filetype_filter(path) do
    path |> Path.extname |> is_accepted_format
  end

  def is_accepted_format(".mp3"), do: true
  def is_accepted_format(".m4a"), do: true
  def is_accepted_format(".flac"), do: true
  def is_accepted_format(".ogg"), do: true
  def is_accepted_format(_), do: false
end
