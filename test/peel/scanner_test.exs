
defmodule Peel.Test.ScannerTest do
  use   ExUnit.Case

  alias Peel.Track
  alias Peel.Album
  alias Peel.Artist
  alias Peel.Repo

  alias Otis.Source.Metadata

  setup do
    Enum.each [Track, Album, Artist], fn(m) -> m.delete_all end
    root = Path.expand(Path.join(__DIR__, "../fixtures/music"))
    metadata = %Metadata{
      album: "Fresh Cream",
      bit_rate: 288000,
      channels: 2,
      composer: "Peter Brown & Jack Bruce",
      date: "1966",
      disk_number: 1,
      disk_total: 1,
      duration_ms: 173662,
      extension: "m4a",
      filename: "01 I Feel Free",
      genre: "Rock",
      mime_type: "audio/mp4",
      performer: "Cream",
      sample_rate: 44100,
      stream_size: 6370536,
      title: "I Feel Free",
      track_number: 1,
      track_total: 11
    }
    paths = Enum.map [
      "Cream/Fresh Cream/01 I Feel Free.m4a"
    ], &Path.join(root, &1)

    {:ok, track_count: 1, root: root, path: List.first(paths), paths: paths, metadata: metadata }
  end

  test "it creates a track for each song file", context do
    Peel.Scanner.create_track(context.path, context.metadata)
    tracks = Track.all
    assert length(tracks) == context.track_count
  end

  test "it assigns a UUID as the primary key", context do
    Peel.Scanner.create_track(context.path, context.metadata)
    [track] = Track.all
    assert is_binary(track.id)
    assert String.length(track.id) == 36
  end

  test "it sets the track data from the file", context do
    Peel.Scanner.create_track(context.path, context.metadata)
    [track] = Track.all
    assert track.title == "I Feel Free"
    assert track.normalized_title == "i feel free"
    assert track.album_title == "Fresh Cream"
    assert track.performer == "Cream"
    assert track.genre == "Rock"
    assert track.composer == "Peter Brown & Jack Bruce"
    assert track.date == "1966"
  end

  test "it sets the mtime from the file", context do
    Peel.Scanner.create_track(context.path, context.metadata)
    [track] = Track.all
    [path | _] = context.paths
    %{mtime: mtime} = File.stat!(path)
    assert track.mtime == Ecto.DateTime.from_erl(mtime)
  end

  test "it correctly sets the track duration", context do
    Peel.Scanner.create_track(context.path, context.metadata)
    [track] = Track.all
    assert track.duration_ms == 173662
  end

  test "it correctly sets the track mime type", context do
    Peel.Scanner.create_track(context.path, context.metadata)
    [track] = Track.all
    assert track.mime_type == "audio/mp4"
  end

  test "it creates an album when one isn't available", context do
    assert length(Album.all) == 0
    Peel.Scanner.create_track(context.path, context.metadata)
    assert length(Album.all) == 1
    track = List.first(context.paths)
            |> Track.by_path
            |> Repo.preload(:album)
    album = track.album
    assert album.title == "Fresh Cream"
    assert album.normalized_title == "fresh cream"
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
    Peel.Scanner.create_track(context.path, context.metadata)
    assert length(Album.all) == 1
    album = Album.first
    album_id = album.id
    Track.delete_all
    Peel.Scanner.create_track(context.path, context.metadata)
    assert length(Album.all) == 1
    track = List.first(context.paths)
            |> Track.by_path
            |> Repo.preload(:album)
    album = track.album |> Repo.preload(:tracks)
    assert album.id == album_id

    assert Enum.map(album.tracks, fn(t) -> t.album_id end) == [album.id]
  end

  test "it uses an existing album based on normalized title", context do
    assert length(Album.all) == 0
    Peel.Scanner.create_track(context.path, context.metadata)
    assert length(Album.all) == 1
    album = Album.first
    album_id = album.id
    Track.delete_all
    Peel.Scanner.create_track(context.path, %Metadata{context.metadata | album: "fresh  cream"})
    assert length(Album.all) == 1
    track = List.first(context.paths)
            |> Track.by_path
            |> Repo.preload(:album)
    album = track.album |> Repo.preload(:tracks)
    assert album.id == album_id

    assert Enum.map(album.tracks, fn(t) -> t.album_id end) == [album.id]
  end

  test "it creates an artist when one isn't available", context do
    assert length(Artist.all) == 0
    Peel.Scanner.create_track(context.path, context.metadata)
    assert length(Artist.all) == 1
    track = List.first(context.paths)
            |> Track.by_path
            |> Repo.preload([:artist, :album])
    artist = track.artist
    assert artist.name == "Cream"
    assert artist.normalized_name == "cream"
    albums = Artist.albums(artist)
    assert albums == [track.album]
  end

  test "it uses an existing artist", context do
    assert length(Artist.all) == 0
    Peel.Scanner.create_track(context.path, context.metadata)
    assert length(Artist.all) == 1
    artist = Artist.first
    Track.delete_all
    Album.delete_all
    Peel.Scanner.create_track(context.path, %Metadata{ context.metadata | title: "White Room", track_number: 2 })
    assert length(Artist.all) == 1
    album = Album.first |> Repo.preload(:tracks)
    assert Album.artists(album) == [artist]
  end

  test "it uses an existing artist based on normalized name", context do
    assert length(Artist.all) == 0
    Peel.Scanner.create_track(context.path, context.metadata)
    assert length(Artist.all) == 1
    artist = Artist.first
    Track.delete_all
    # Album.delete_all
    Peel.Scanner.create_track(context.path, %Metadata{ context.metadata | performer: "cream", title: "White Room", track_number: 2 })
    assert length(Artist.all) == 1
    assert length(Album.all) == 1
    album = Album.first |> Repo.preload(:tracks)
    assert Album.artists(album) == [artist]
  end

  test "it handles tracks with blank artists", context do
    path = Path.join(context.root, "../broken/missing_disk_number")
    metadata = %Metadata{
      album: "the world of Thomas Tallis",
      bit_rate: 128000,
      channels: 2,
      composer: "Kings College Choir/Thomas Tallis",
      date: nil,
      disk_number: nil,
      disk_total: nil,
      duration_ms: 697667,
      extension: "m4a",
      filename: "01 Spem in alium",
      genre: "Classical",
      mime_type: "audio/mp4",
      performer: nil,
      sample_rate: 44100,
      stream_size: 11108509,
      title: "Spem in alium",
      track_number: 1,
      track_total: 11 }
    Peel.Scanner.create_track(path, metadata)
    tracks = Track.all
    assert length(tracks) == 1
    [track] = tracks
    assert track.performer == "Unknown artist"
  end

  test "it handles tracks with blank titles", context do
    path = Path.join(context.root, "../broken/missing_disk_number")
    metadata = %Metadata{
      album: "the world of Thomas Tallis",
      bit_rate: 128000,
      channels: 2,
      composer: "Kings College Choir/Thomas Tallis",
      date: nil,
      disk_number: nil,
      disk_total: nil,
      duration_ms: 697667,
      extension: "m4a",
      filename: "01 Spem in alium",
      genre: "Classical",
      mime_type: "audio/mp4",
      performer: "Various Artists",
      sample_rate: 44100,
      stream_size: 11108509,
      title: nil,
      track_number: 1,
      track_total: 11 }
    Peel.Scanner.create_track(path, metadata)
    tracks = Track.all
    assert length(tracks) == 1
    [track] = tracks
    assert track.title == "Untitled"
  end

  test "it handles tracks with no disk number", context do
    path = Path.join(context.root, "../broken/missing_disk_number")
    metadata = %Metadata{
      album: "the world of Thomas Tallis",
      bit_rate: 128000,
      channels: 2,
      composer: "Kings College Choir/Thomas Tallis",
      date: nil,
      disk_number: nil,
      disk_total: nil,
      duration_ms: 697667,
      extension: "m4a",
      filename: "01 Spem in alium",
      genre: "Classical",
      mime_type: "audio/mp4",
      performer: "Various Artists",
      sample_rate: 44100,
      stream_size: 11108509,
      title: "Spem in alium",
      track_number: 1,
      track_total: 11 }
    Peel.Scanner.create_track(path, metadata)
    assert length(Track.all) == 1
    track = Track.first |> Repo.preload(:album)
    assert track.album.disk_number == 1
  end

  test "it handles tracks with an unknown artist", context do
    path = Path.join(context.root, "../broken/unknown_artist")
    metadata = %Metadata{
      album: "14 Classic Carols",
      bit_rate: 281594,
      channels: 2,
      duration_ms: 182416,
      extension: "m4a",
      filename: "01 Once in Royal David_s City",
      mime_type: "audio/mp4",
      sample_rate: 44100,
      stream_size: 6420903,
      title: "Once in Royal David’s City",
      track_number: 1,
      track_total: 14 }
    Peel.Scanner.create_track(path, metadata)
    assert length(Track.all) == 1
    track = Track.first |> Repo.preload(:album)
    album = track.album
    assert track.performer == "Unknown artist"
    assert album.performer == "Unknown artist"
    [artist] = Album.artists(album)
    assert artist.name == "Unknown artist"
  end

  test "it assigns the album cover image to new tracks", context do
    Peel.Scanner.create_track(context.path, context.metadata)
    album = Album.first
    Album.change(album, %{cover_image: "/path/to/cover.jpg"}) |> Peel.Repo.update
    Track.delete_all
    Peel.Scanner.create_track(context.path, context.metadata)
    assert length(Album.all) == 1
    track = List.first(context.paths)
            |> Track.by_path
    assert track.cover_image == "/path/to/cover.jpg"
  end

  test "it strips whitespace from all fields", context do
    path = Path.join(context.root, "../broken/unknown_artist")
    metadata = %Metadata{
      album: " Fresh Cream ",
      bit_rate: 288000,
      channels: 2,
      composer: " Peter Brown & Jack Bruce ",
      date: "1966",
      disk_number: 1,
      disk_total: 1,
      duration_ms: 173662,
      extension: "m4a",
      filename: " 01 I Feel Free ",
      genre: "Rock",
      mime_type: "audio/mp4",
      performer: " Cream ",
      sample_rate: 44100,
      stream_size: 6370536,
      title: " I Feel Free ",
      track_number: 1,
      track_total: 11
    }
    Peel.Scanner.create_track(path, metadata)
    assert length(Track.all) == 1
    track = Track.first |> Repo.preload(:album)
    assert track.performer == "Cream"
    assert track.album_title == "Fresh Cream"
    assert track.composer == "Peter Brown & Jack Bruce"
    assert track.title == "I Feel Free"
    album = track.album
    assert album.performer == "Cream"
    assert album.title == "Fresh Cream"
    [artist] = Album.artists(album)
    assert artist.name == "Cream"
  end

  test "it strips leading 'the' from performer names", context do
    path = Path.join(context.root, "../broken/unknown_artist")
    metadata = %Metadata{
      album: " Fresh Cream ",
      bit_rate: 288000,
      channels: 2,
      composer: " Peter Brown & Jack Bruce ",
      date: "1966",
      disk_number: 1,
      disk_total: 1,
      duration_ms: 173662,
      extension: "m4a",
      filename: " 01 I Feel Free ",
      genre: "Rock",
      mime_type: "audio/mp4",
      performer: "The Beatles",
      sample_rate: 44100,
      stream_size: 6370536,
      title: " I Feel Free ",
      track_number: 1,
      track_total: 11
    }
    Peel.Scanner.create_track(path, metadata)
    assert length(Track.all) == 1
    track = Track.first |> Repo.preload(:album)
    assert track.performer == "The Beatles"
    album = track.album
    [artist] = Album.artists(album)
    assert artist.name == "The Beatles"
    assert artist.normalized_name == "beatles"
  end
end
