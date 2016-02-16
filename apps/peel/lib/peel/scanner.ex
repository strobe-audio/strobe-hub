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
    path |> Peel.Track.from_path |> track(path)
  end

  def track(nil, path) do
    track = path |> metadata |> Enum.into(track_for_path(path))

    {:ok, _track} = Peel.Repo.transaction fn ->
      track |> Album.for_track |> Track.create!
    end
  end
  def track(%Peel.Track{}, _path) do
    # Exists - TODO: should check mtime for modifications and act...
  end

  def metadata(path) do
    path
    |> Otis.Source.File.metadata!
    |> Map.from_struct
    # Reject any nil values so that they don't overwrite defaults
    |> Enum.reject(fn({_, v}) -> is_nil(v) end)
    |> Enum.map(&translate_metadata_key/1)
  end

  # We reserve %Track.album to point to the album relation
  def translate_metadata_key({:album, album}), do: {:album_title, album}
  def translate_metadata_key(term), do: term

  def track_for_path(path) do
    stat = File.stat!(path)
    %Track{mtime: Ecto.DateTime.from_erl(stat.mtime), path: path}
  end

  def filetype_filter(path) do
    path |> Path.extname |> is_accepted_format
  end

  def is_accepted_format(".mp3"), do: true
  def is_accepted_format(".m4a"), do: true
  def is_accepted_format(".flac"), do: true
  def is_accepted_format(".ogg"), do: true
  def is_accepted_format(_), do: false
end
