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
        date: "1987", disk_number: 1, disk_total: 1, genre: "Rock",
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
        date: "1977", disk_number: 1, disk_total: 1, duration_ms: 169227,
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

    channel_id = "6df968bf-3454-4514-940b-4829dfcf4d3c"

    channels = [
      %Otis.State.Channel{ id: channel_id,
        name: "Sorry I Burnt Your Nose",
        position: 0, volume: 0.40037950664136623},
    ]
    Enum.each channels, &Otis.State.Repo.insert!/1

    {:ok, channel_id: channel_id}
  end

  def track_node(%Track{} = track) do
    %{action: "peel:track/#{track.id}",
     icon: track.cover_image,
     id: "peel:track/#{track.id}",
     title: track.title }
  end

  test "track_node" do
    track = Track.find("94499562-d2c5-41f8-b07c-ecfbecf0c428")
    assert track_node(track) == %{
     action: "peel:track/94499562-d2c5-41f8-b07c-ecfbecf0c428",
     icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
     id: "peel:track/94499562-d2c5-41f8-b07c-ecfbecf0c428",
     title: "Uh-Oh, Love Comes To Town" }
  end

  test "peel:root", context do
    path = "root"
    response = Library.route_library_request(context.channel_id, path)
    assert response == %{
      id: "peel:root",
      title: "Your Music",
      icon: "",
      children: [
        %{ id: "peel:albums", title: "Albums", icon: "", action: "peel:albums" },
        %{ id: "peel:artists", title: "Artists", icon: "", action: "peel:artists" },
      ],
    }
  end

  test "peel:albums", context do
    path = "albums"
    response = Library.route_library_request(context.channel_id, path)

    assert response == %{
      id: path,
      title: "Albums",
      icon: "",
      children: [
        %{action: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898",
         icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
         id: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898",
         title: "Talking Heads: 77",
         metadata: [
           [{"Talking Heads", "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e"}]
         ],
       },
       %{action: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
        id: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        title: "Some Compilation",
        metadata: [
          [ {"Echo and the Bunnymen", "peel:artist/ece2ce41-3194-4506-9e16-42e56e1be090"},
            {"Talking Heads", "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e"},
            {"The Lurkers", "peel:artist/b408ec33-f533-49f6-944b-5d829139e1de"}
          ],
        ],
      },
    ],
  }
  end

  test "peel:album/{album_id}", context do
    album = Album.find("7aed1ef3-de88-4ea8-9af7-29a1327a5898")
    path = "album/#{album.id}"
    response = Library.route_library_request(context.channel_id, path)

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
    response = Library.route_library_request(context.channel_id, path)
    assert response == %{
      id: path,
      title: "Artists",
      # icon: artist.cover_image,
      icon: "",
      children: [
        %{ id: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e",
          action: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e",
          icon: "", title: "Talking Heads"},
        %{ id: "peel:artist/ece2ce41-3194-4506-9e16-42e56e1be090",
          action: "peel:artist/ece2ce41-3194-4506-9e16-42e56e1be090",
          icon: "", title: "Echo and the Bunnymen"},
        %{ id: "peel:artist/b408ec33-f533-49f6-944b-5d829139e1de",
          action: "peel:artist/b408ec33-f533-49f6-944b-5d829139e1de",
          icon: "", title: "The Lurkers"},
      ],
    }
  end

  test "peel:artist/{artist_id}", context do
    artist = Artist.find("fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e")
    path = "artist/#{artist.id}"
    response = Library.route_library_request(context.channel_id, path)

    assert response == %{
      id: path,
      title: artist.name,
      # icon: artist.cover_image,
      icon: "",
      children: [
        %{action: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e",
         icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
         id: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898",
         title: "Talking Heads: 77",
         # subtitle: [
         #   {"Talking Heads", "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e"}
         # ],
       },
       %{action: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e",
        icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
        id: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        title: "Some Compilation",
        # subtitle: [
        #   {"Echo and the Bunnymen", "peel:artist/ece2ce41-3194-4506-9e16-42e56e1be090"},
        #   {"Talking Heads", "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e"},
        #   {"The Lurkers", "peel:artist/b408ec33-f533-49f6-944b-5d829139e1de"},
        # ]
      }
    ],
    }
  end

  test "peel:album/{album_id}/artist/{artist_id}", context do
    artist = Artist.find("fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e")
    album = Album.find("1f74a72a-800d-443e-9bb2-4fc5e10ff43d")
    path = "album/#{album.id}/artist/#{artist.id}"
    response = Library.route_library_request(context.channel_id, path)

    assert response == %{
      id: path,
      title: album.title,
      icon: album.cover_image,
      children: [
        track_node(Track.find("0a89f07e-0f5e-48c4-8b00-d83026a90724")),
      ],
    }
  end
end
