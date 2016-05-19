defmodule Peel.Scanner do
  alias Peel.Track
  alias Peel.Album

  def start(path) do
    path |> stream |> Enum.each(&scan/1)
  end

  def stream(path) do
    path
    |> List.wrap
    |> Peel.DirWalker.stream
    |> Stream.filter(&filetype_filter/1)
  end

  def scan(path) do
    Peel.Repo.transaction fn ->
      path |> Peel.Track.by_path |> track(path)
    end
  end

  def track(nil, path) do
    create_track(path, metadata(path))
  end
  def track(%Peel.Track{} = track, _path) do
    # Exists - TODO: should check mtime for modifications and act...
    track
  end

  def create_track(path, path_metadata) do
    IO.inspect path_metadata
    path
    |> Track.new
    |> struct(clean_metadata(path_metadata))
    |> Album.for_track
    |> Track.create!
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
