
defmodule Peel.Test.ScannerTest do
  use   ExUnit.Case

  alias Peel.Track
  alias Peel.Album
  alias Peel.Artist
  alias Peel.Repo

  setup do
    Enum.each [Track, Album, Artist], fn(m) -> m.delete_all end
    path = Path.expand(Path.join(__DIR__, "../fixtures/music"))
    paths = Enum.map [
      "Cream/Fresh Cream/01 I Feel Free.m4a"
    ], &Path.join(path, &1)
    {:ok, track_count: 1, path: path, paths: paths}
  end

  test "it creates a track for each song file", context do
    Peel.Scanner.start(context.path)
    tracks = Track.all
    assert length(tracks) == context.track_count
  end

  test "it creates an album when one isn't available", context do
    assert length(Album.all) == 0
    Peel.Scanner.start(context.path)
    assert length(Album.all) == 1
    track = List.first(context.paths)
            |> Track.from_path
            |> Repo.preload(:album)
    album = track.album
    assert album.title == "Fresh Cream"
    assert album.disk_number == 1
    assert album.disk_total == 1
    assert album.genre == "Rock"
    assert album.performer == "Cream"
    assert album.title == "Fresh Cream"
    assert album.track_total == 11
    album = album |> Repo.preload(:tracks)
    assert Enum.map(album.tracks, fn(t) -> t.id end) == [track.id]
  end

  test "it uses an existing album", context do
    assert length(Album.all) == 0
    Peel.Scanner.start(context.path)
    assert length(Album.all) == 1
    album = Album.first
    album_id = album.id
    Track.delete_all
    Peel.Scanner.start(context.path)
    assert length(Album.all) == 1
    track = List.first(context.paths)
            |> Track.from_path
            |> Repo.preload(:album)
    album = track.album |> Repo.preload(:tracks)
    assert album.id == album_id

    assert Enum.map(album.tracks, fn(t) -> t.album_id end) == [album.id]
  end

  test "it creates an artist when one isn't available", context do
    assert length(Artist.all) == 0
    Peel.Scanner.start(context.path)
    assert length(Artist.all) == 1
    track = List.first(context.paths)
            |> Track.from_path
            |> Repo.preload(:album)
    album = track.album |> Repo.preload(:artist)
    artist = album.artist
    assert artist.name == "Cream"
    artist = artist |> Repo.preload(:albums)
    assert Enum.map(artist.albums, fn(a) -> a.id end) == [album.id]
  end

  test "it uses an existing artist", context do
    assert length(Artist.all) == 0
    Peel.Scanner.start(context.path)
    assert length(Artist.all) == 1
    artist = Artist.first
    artist_id = artist.id
    Track.delete_all
    Album.delete_all
    Peel.Scanner.start(context.path)
    assert length(Artist.all) == 1
    album = Album.first |> Repo.preload(:tracks)
    assert album.artist_id == artist_id
  end

  test "it handles tracks with no disk number", context do
    path = Path.join(context.path, "../broken/missing_disk_number")
    Peel.Scanner.start(path)
    assert length(Track.all) == 1
    track = Track.first |> Repo.preload(:album)
    assert track.album.disk_number == 1
  end

  test "it handles tracks with an unknown artist", context do
    path = Path.join(context.path, "../broken/unknown_artist")
    Peel.Scanner.start(path)
    assert length(Track.all) == 1
    track = Track.first |> Repo.preload(:album)
    album = track.album
    assert track.performer == "Unknown artist"
    assert album.performer == "Unknown artist"
    album = album |> Repo.preload(:artist)
    artist = album.artist
    assert artist.name == "Unknown artist"
  end
end
