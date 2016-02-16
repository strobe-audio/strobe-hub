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
    # TODO: REMOVE REMOVE REMOVE
    # |> Stream.take(5)
  end

  def scan(path) do
    path |> Peel.Track.from_path |> track(path)
  end

  def track(nil, path) do
    file = Otis.Source.File.new!(path)
    meta = Map.from_struct(file.metadata)

    # TODO: improve this ...
    fields = Enum.filter Map.keys(Track.__struct__), fn
      :__meta__   -> false
      :__struct__ -> false
      :album      -> false
      :mtime      -> false
      :path       -> false
      _ -> true
    end
    track = Enum.reduce fields, track_for_path(path), fn(key, t) ->
      case Map.get(meta, map_metadata(t, key)) do
        nil   -> t
        value -> Map.put(t, key, value)
      end
    end
    {:ok, _track} = Peel.Repo.transaction fn ->
      track |> Album.for_track |> Track.create!
    end
  end

  def track(%Peel.Track{}, _path) do
    # Exists - TODO: should check mtime for modifications and act...
  end

  def track_for_path(path) do
    stat = File.stat!(path)
    %Track{mtime: Ecto.DateTime.from_erl(stat.mtime), path: path}
  end

  def map_metadata(%Track{}, :album_title), do: :album
  def map_metadata(_struct, key) do
    key
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
