defmodule Peel.Test.LibraryTest do
  use ExUnit.Case, async: false

  alias Peel.Repo
  alias Peel.Album
  alias Peel.Track
  alias Peel.Artist
  alias Peel.Events.Library

  setup_all do
    Ecto.Adapters.SQL.restart_test_transaction(Peel.Repo)

    on_exit fn ->
      Ecto.Adapters.SQL.rollback_test_transaction(Peel.Repo)
    end

    artists = [
      %Artist{
        id: "fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", name: "Talking Heads",
        normalized_name: "talking heads" },
      %Artist{
        id: "ece2ce41-3194-4506-9e16-42e56e1be090", name: "Echo and the Bunnymen",
        normalized_name: "echo and the bunnymen" },
      %Artist{
        id: "b408ec33-f533-49f6-944b-5d829139e1de", name: "The Lurkers",
        normalized_name: "the lurkers" },
    ]
    Enum.each artists, &Repo.insert!/1

    albums = [
      %Album{ id: "7aed1ef3-de88-4ea8-9af7-29a1327a5898",
        date: "1977", disk_number: 1, disk_total: 1, genre: "Rock",
        normalized_title: "talking heads 77", performer: "Talking Heads",
        cover_image: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
        title: "Talking Heads: 77", track_total: 2 },
      %Album{ id: "1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        date: nil, disk_number: 1, disk_total: 1, genre: "Rock",
        normalized_title: "some compilation", performer: "Various Artists",
        cover_image: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
        title: "Some Compilation", track_total: 3 },
    ]
    Enum.each albums, &Repo.insert!/1

    tracks = [
      %Peel.Track{ id: "94499562-d2c5-41f8-b07c-ecfbecf0c428",
        album_id: "7aed1ef3-de88-4ea8-9af7-29a1327a5898",
        album_title: "Talking Heads: 77",
        artist_id: "fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", composer: "David Byrne",
        cover_image: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
        date: "1977", disk_number: 1, disk_total: 1, duration_ms: 159000,
        genre: "Rock", mime_type: "audio/mp4",
        normalized_title: "uh oh love comes to town",
        path: "iTunes/iTunes Media/Music/Talking Heads/Talking Heads_ 77/01 Uh-Oh, Love Comes To Town.m4a",
        performer: "Talking Heads", title: "Uh-Oh, Love Comes To Town",
        track_number: 1, track_total: 11},
      %Peel.Track{ id: "a3c90ce4-8a98-405f-bffd-04bc744c13df",
        album_id: "7aed1ef3-de88-4ea8-9af7-29a1327a5898",
        album_title: "Talking Heads: 77",
        artist_id: "fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", composer: "David Byrne",
        cover_image: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
        date: "1977", disk_number: 1, disk_total: 1, duration_ms: 189336,
        genre: "Rock", mime_type: "audio/mp4",
        normalized_title: "new feeling",
        path: "iTunes/iTunes Media/Music/Talking Heads/Talking Heads_ 77/02 New Feeling.m4a",
        performer: "Talking Heads", title: "New Feeling", track_number: 2,
        track_total: 11},

      %Peel.Track{ id: "63f49bae-fcbf-49df-94c9-668c52f3e125",
        album_id: "1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        album_title: "Some Compilation",
        artist_id: "ece2ce41-3194-4506-9e16-42e56e1be090", composer: "Ian McCulloch",
        cover_image: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
        date: "1987", disk_number: 1, disk_total: 1, duration_ms: 189336,
        genre: "Rock", mime_type: "audio/mp4",
        normalized_title: "going up",
        path: "iTunes/iTunes Media/Music/Various Artists/Some Compilation/Going Up.m4a",
        performer: "Echo and the Bunnymen", title: "Going Up", track_number: 1,
        track_total: 3},
      %Peel.Track{ id: "59afcd1e-9f6f-4df5-9ece-5f874d6e36bd",
        album_id: "1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        album_title: "Some Compilation",
        artist_id: "b408ec33-f533-49f6-944b-5d829139e1de", composer: "Pete Stride",
        cover_image: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
        date: "1987", disk_number: 1, disk_total: 1, duration_ms: 189336,
        genre: "Rock", mime_type: "audio/mp4",
        normalized_title: "aint got a clue",
        path: "iTunes/iTunes Media/Music/Various Artists/Some Compilation/Ain't Got a Clue.m4a",
        performer: "The Lurkers", title: "Ain't Got a Clue", track_number: 2,
        track_total: 3},
      %Peel.Track{ id: "0a89f07e-0f5e-48c4-8b00-d83026a90724",
        album_id: "1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        album_title: "Some Compilation",
        artist_id: "fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", composer: "David Byrne",
        cover_image: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
        date: "1987", disk_number: 1, disk_total: 1, duration_ms: 189336,
        genre: "Rock", mime_type: "audio/mp4",
        normalized_title: "uh oh love comes to town",
        path: "iTunes/iTunes Media/Music/Various Artists/Some Compilation/Uh-Oh, Love Comes To Town.m4a",
        performer: "Talking Heads", title: "Uh-Oh, Love Comes To Town",
        track_number: 3, track_total: 3},
    ]
    Enum.each tracks, &Repo.insert!/1

    album_artists = [
      %Peel.AlbumArtist{
        album_id: "7aed1ef3-de88-4ea8-9af7-29a1327a5898",
        artist_id: "fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", id: 1352},

      %Peel.AlbumArtist{
        album_id: "1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        artist_id: "ece2ce41-3194-4506-9e16-42e56e1be090", id: 1353},
      %Peel.AlbumArtist{
        album_id: "1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        artist_id: "b408ec33-f533-49f6-944b-5d829139e1de", id: 1354},
      %Peel.AlbumArtist{
        album_id: "1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        artist_id: "fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", id: 1355},
    ]

    Enum.each album_artists, &Repo.insert!/1

    Otis.State.Channel.delete_all

    channel_id = "6df968bf-3454-4514-940b-4829dfcf4d3c"

    channels = [
      %Otis.State.Channel{ id: channel_id,
        name: "Sorry I Burnt Your Nose",
        position: 0, volume: 0.40037950664136623},
    ]
    Enum.each channels, &Otis.State.Repo.insert!/1

    Enum.each Otis.State.Channel.all, fn(channel) ->
      Otis.Channels.start(channel.id, channel)
    end

    on_exit fn ->
      Enum.each Otis.State.Channel.all, fn(channel) ->
        Otis.Channels.destroy!(channel.id)
      end
    end

    {:ok, channel_id: channel_id}
  end

  setup context do
    TestEventHandler.attach
    on_exit fn ->
      with {:ok, channel} <- Otis.Channels.find(context.channel_id),
           {:ok, source_list} <- Otis.Channel.source_list(channel)
      do
        Otis.SourceList.clear(source_list)
      end
    end
    :ok
  end

  def track_node(%Track{} = track) do
    %{actions: %{ click: "peel:track/#{track.id}/play", play: "peel:track/#{track.id}/play" },
     icon: track.cover_image,
     id: "peel:track/#{track.id}",
     title: track.title,
     metadata: [
      [%{title: Peel.Duration.hms_ms(track.duration_ms), action: nil}],
     ]
   }
  end

  test "track_node" do
    track = Track.find("94499562-d2c5-41f8-b07c-ecfbecf0c428")
    assert track_node(track) == %{
     actions: %{ click: "peel:track/94499562-d2c5-41f8-b07c-ecfbecf0c428/play", play: "peel:track/94499562-d2c5-41f8-b07c-ecfbecf0c428/play" },
     icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
     id: "peel:track/94499562-d2c5-41f8-b07c-ecfbecf0c428",
     title: "Uh-Oh, Love Comes To Town",
     metadata: [
      [%{ title: "02:39", action: nil}]
     ],
   }
  end

  test "peel:root", context do
    path = "root"
    response = Library.handle_request(context.channel_id, path)
    assert response == %{
      id: "peel:root",
      title: "Your Music",
      icon: "",
      children: [
        %{ id: "peel:albums", title: "Albums", icon: "", actions: %{ click: "peel:albums", play: nil }, metadata: nil },
        %{ id: "peel:artists", title: "Artists", icon: "", actions: %{ click: "peel:artists", play: nil }, metadata: nil },
      ],
    }
  end

  test "peel:albums", context do
    path = "albums"
    response = Library.handle_request(context.channel_id, path)

    assert response == %{
      id: path,
      title: "Albums",
      icon: "",
      children: [
        %{ actions: %{
            click: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898",
            play:  "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/play",
          },
         icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
         id: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898",
         title: "Talking Heads: 77",
         metadata: [
           [%{title: "Talking Heads", action: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e"}],
           [%{title: "1977", action: nil}]
         ],
       },
       %{ actions: %{
           click: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
           play: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d/play",
         },
        icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
        id: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        title: "Some Compilation",
        metadata: [
          [ %{title: "Various Artists", action: nil} ],
        ],
      },
    ],
  }
  end

  test "peel:album/{album_id}", context do
    album = Album.find("7aed1ef3-de88-4ea8-9af7-29a1327a5898")
    path = "album/#{album.id}"
    response = Library.handle_request(context.channel_id, path)

    assert response == %{
      id: path,
      title: album.title,
      icon: album.cover_image,
      children: [
        track_node(Track.find("94499562-d2c5-41f8-b07c-ecfbecf0c428")),
        track_node(Track.find("a3c90ce4-8a98-405f-bffd-04bc744c13df")),
      ],
    }
  end

  test "peel:artists", context do
    path = "artists"
    response = Library.handle_request(context.channel_id, path)
    assert response == %{
      id: path,
      title: "Artists",
      # icon: artist.cover_image,
      icon: "",
      children: [
        %{ id: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e",
          actions: %{ click: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", play: nil },
          icon: "", title: "Talking Heads", metadata: nil},
        %{ id: "peel:artist/ece2ce41-3194-4506-9e16-42e56e1be090",
          actions: %{ click: "peel:artist/ece2ce41-3194-4506-9e16-42e56e1be090", play: nil },
          icon: "", title: "Echo and the Bunnymen", metadata: nil},
        %{ id: "peel:artist/b408ec33-f533-49f6-944b-5d829139e1de",
          actions: %{ click: "peel:artist/b408ec33-f533-49f6-944b-5d829139e1de", play: nil },
          icon: "", title: "The Lurkers", metadata: nil},
      ],
    }
  end

  test "peel:artist/{artist_id}", context do
    artist = Artist.find("fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e")
    path = "artist/#{artist.id}"
    response = Library.handle_request(context.channel_id, path)

    assert response == %{
      id: path,
      title: artist.name,
      # icon: artist.cover_image,
      icon: "",
      children: [
        %{actions: %{ click: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", play: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e/play" },
         icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
         id: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898",
         title: "Talking Heads: 77",
         metadata: [
           [%{title: "1977", action: nil}]
         ],
       },
       %{actions: %{ click: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", play: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e/play" },
        icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
        id: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        title: "Some Compilation",
        metadata: nil,
      }
    ],
    }
  end

  test "peel:album/{album_id}/artist/{artist_id}", context do
    artist = Artist.find("fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e")
    album = Album.find("1f74a72a-800d-443e-9bb2-4fc5e10ff43d")
    path = "album/#{album.id}/artist/#{artist.id}"
    response = Library.handle_request(context.channel_id, path)

    assert response == %{
      id: path,
      title: album.title,
      icon: album.cover_image,
      children: [
        track_node(Track.find("0a89f07e-0f5e-48c4-8b00-d83026a90724")),
      ],
    }
  end

  test "peel:track/{track_id}/play", %{channel_id: channel_id} = _context do
    track = Track.find("94499562-d2c5-41f8-b07c-ecfbecf0c428")
    path = "track/#{track.id}/play"
    Library.handle_request(channel_id, path)
    assert_receive {:new_rendition, [^channel_id, 0, {_, 0, ^track}]}
  end

  test "peel:album/{album_id}/play", %{channel_id: channel_id} = _context do
    album = Album.find("7aed1ef3-de88-4ea8-9af7-29a1327a5898")
    path = "album/#{album.id}/play"
    Library.handle_request(channel_id, path)

    [track1, track2] = [
      Track.find("94499562-d2c5-41f8-b07c-ecfbecf0c428"),
      Track.find("a3c90ce4-8a98-405f-bffd-04bc744c13df"),
    ]

    assert_receive {:new_rendition, [^channel_id, 0, {_, 0, ^track1}]}
    assert_receive {:new_rendition, [^channel_id, 1, {_, 0, ^track2}]}
  end
end
