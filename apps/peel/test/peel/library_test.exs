defmodule Peel.Test.LibraryTest do
  use ExUnit.Case, async: false

  alias Peel.Repo
  alias Peel.Collection
  alias Peel.Album
  alias Peel.Track
  alias Peel.Artist
  alias Peel.Events.Library

  setup  do
    channel_id = "6df968bf-3454-4514-940b-4829dfcf4d3c"

    Ecto.Adapters.SQL.restart_test_transaction(Peel.Repo)
    # Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)

    on_exit fn ->
      Ecto.Adapters.SQL.rollback_test_transaction(Peel.Repo)
      # Ecto.Adapters.SQL.rollback_test_transaction(Otis.State.Repo)
    end
    Collection.delete_all

    root = Path.expand(Path.join(__DIR__, "../fixtures/music"))
    collection = %Collection{name: "My Music", id: Ecto.UUID.generate(), path: root} |> Repo.insert!
    other_collection = %Collection{name: "Other Music", id: Ecto.UUID.generate(), path: root} |> Repo.insert!

    artists = [
      %Artist{
        collection_id: collection.id,
        id: "fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", name: "Talking Heads",
        normalized_name: "talking heads" },
      %Artist{
        collection_id: collection.id,
        id: "ece2ce41-3194-4506-9e16-42e56e1be090", name: "Echo and the Bunnymen",
        normalized_name: "echo and the bunnymen" },
      %Artist{
        collection_id: collection.id,
        id: "b408ec33-f533-49f6-944b-5d829139e1de", name: "The Lurkers",
        normalized_name: "the lurkers" },
    ]
    Enum.each artists, &Repo.insert!/1

    albums = [
      %Album{ id: "7aed1ef3-de88-4ea8-9af7-29a1327a5898",
        collection_id: collection.id,
        date: "1977", disk_number: 1, disk_total: 1, genre: "Rock",
        normalized_title: "talking heads 77", performer: "Talking Heads",
        cover_image: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
        title: "Talking Heads: 77", track_total: 2 },
      %Album{ id: "1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
        collection_id: collection.id,
        date: nil, disk_number: 1, disk_total: 1, genre: "Rock",
        normalized_title: "some compilation", performer: "Various Artists",
        cover_image: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
        title: "Some Compilation", track_total: 3 },
    ]
    Enum.each albums, &Repo.insert!/1

    tracks = [
      %Peel.Track{ id: "94499562-d2c5-41f8-b07c-ecfbecf0c428",
        collection_id: collection.id,
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
        collection_id: collection.id,
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
        collection_id: collection.id,
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
        collection_id: collection.id,
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
        collection_id: collection.id,
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

    # Otis.State.Channel.delete_all

    channels = [
      %Otis.State.Channel{ id: channel_id,
        name: "Sorry I Burnt Your Nose",
        position: 0, volume: 0.40037950664136623},
    ]
    # Enum.each channels, &Otis.State.Repo.insert!/1

    Enum.each channels, fn(channel) ->
      Otis.Channels.start(channel)
    end

    on_exit fn ->
      nil
      # Enum.each Otis.State.Channel.all, fn(channel) ->
        # Otis.Channels.destroy!(channel.id)
      # end
    end
    TestEventHandler.attach

    # on_exit fn ->
    #   with {:ok, channel} <- Otis.Channels.find(channel_id),
    #        {:ok, playlist} <- Otis.Channel.playlist(channel)
    #   do
    #     Otis.Pipeline.Playlist.clear(playlist)
    #   end
    # end

    {:ok, channel_id: channel_id, collection: collection, other_collection: other_collection}
  end

  def track_node(%Track{} = track) do
    %{ title: track.title,
     actions: %{
       click: %{level: false, url: "peel:track/#{track.id}/play"},
       play: %{level: false, url: "peel:track/#{track.id}/play"}
     },
     icon: nil, # track.cover_image,
     metadata: [
      [%{title: Otis.Library.Duration.hms_ms(track.duration_ms), action: nil}],
     ]
   }
  end

  test "track_node" do
    track = Track.find("94499562-d2c5-41f8-b07c-ecfbecf0c428")
    assert track_node(track) == %{
     actions: %{
       click: %{url: "peel:track/94499562-d2c5-41f8-b07c-ecfbecf0c428/play", level: false},
       play: %{url: "peel:track/94499562-d2c5-41f8-b07c-ecfbecf0c428/play", level: false}
     },
     icon: nil, # "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
     title: "Uh-Oh, Love Comes To Town",
     metadata: [
      [%{ title: "02:39", action: nil}]
     ],
   }
  end

  test "library", cxt do
    response = Library.library
    coll1 =
      %{ title: cxt.collection.name,
        id: "peel:collection/#{cxt.collection.id}",
        size: "m",
        icon: "",
        actions: %{
          click: %{url: "peel:collection/#{cxt.collection.id}", level: true},
          play: nil
        },
        metadata: nil, # put counts here?
        length: 0,
        children: [],
      }
    coll2 =
      %{ title: cxt.other_collection.name,
        id: "peel:collection/#{cxt.other_collection.id}",
        size: "m",
        icon: "",
        actions: %{
          click: %{url: "peel:collection/#{cxt.other_collection.id}", level: true},
          play: nil
        },
        metadata: nil, # put counts here?
        length: 0,
        children: [],
      }
    assert response == %{
      id: "peel",
      title: "Local Music",
      icon: "",
      size: "s",
      actions: nil,
      metadata: nil,
      children: [
        coll1,
        coll2,
      ],
      length: 2,
    }

  end

  test "peel:collection/:collection_id", context do
    path = "collection/#{context.collection.id}"
    response = Library.handle_request(context.channel_id, path)
    assert response == %{
      id: "peel:#{path}",
      title: context.collection.name,
      icon: "",
      search: %{ title: context.collection.name, url: "peel:search/#{context.collection.id}"},
      length: 2,
      children: [
        %{title: "Albums",
          id: "peel:collection/#{context.collection.id}/albums",
          size: "m",
          icon: "",
          actions: %{
            click: %{url: "peel:collection/#{context.collection.id}/albums", level: true},
            play: nil
          },
          metadata: nil,
          length: 0,
          children: [],
        },
        %{title: "Artists",
          id: "peel:collection/#{context.collection.id}/artists",
          size: "m",
          icon: "",
          actions: %{
            click: %{url: "peel:collection/#{context.collection.id}/artists", level: true},
            play: nil
          },
          metadata: nil,
          length: 0,
          children: [],
        },
      ]
    }
  end

  test "peel:collection/:collection_id/albums", context do
    path = "collection/#{context.collection.id}/albums"
    response = Library.handle_request(context.channel_id, path)

    assert response == %{
      id: "peel:" <> path,
      title: "Albums",
      icon: "",
      search: %{ title: "albums", url: "peel:search/#{context.collection.id}/albums"},
      children: [
        %{title: "S",
          id: "peel:albums:S",
          size: "s",
          icon: nil,
          metadata: nil,
          actions: nil,
          length: 1,
          children: [
            %{ title: "Some Compilation",
              actions: %{
                click: %{url: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d", level: true},
                play: %{url: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d/play", level: false},
              },
              icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
              metadata: [
                [ %{title: "Various Artists", action: nil} ],
              ],
            },
          ]
        },
        %{ title: "T",
          id: "peel:albums:T",
          size: "s",
          icon: nil,
          metadata: nil,
          actions: nil,
          length: 1,
          children: [
              %{ title: "Talking Heads: 77",
                actions: %{
                  click: %{url: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898", level: true},
                  play:  %{url: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/play", level: false},
                },
              icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
              metadata: [
                [%{title: "Talking Heads", action: %{url: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", level: true}}],
                [%{title: "1977", action: nil}]
              ],
            },
          ]
        }
      ]
    }
  end

  test "peel:album/{album_id}", context do
    album = Album.find("7aed1ef3-de88-4ea8-9af7-29a1327a5898")
    path = "album/#{album.id}"
    response = Library.handle_request(context.channel_id, path)

    assert response == %{
      id: "peel:" <> path,
      title: album.title,
      icon: album.cover_image,
      search: nil,
      children: [
        %{ title: album.title,
          id: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898",
          size: "h",
          icon: album.cover_image,
          length: 2,
          metadata: [
            [%{title: "Talking Heads", action: %{url: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", level: true}}],
            [%{title: "1977", action: nil}]
          ],
          actions: %{
            click: %{url: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/play", level: false},
            play: %{url: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/play", level: false},
          },
          children: [
            track_node(Track.find("94499562-d2c5-41f8-b07c-ecfbecf0c428")),
            track_node(Track.find("a3c90ce4-8a98-405f-bffd-04bc744c13df")),
          ],
        }
      ],
    }
  end

  test "peel:artists", context do
    path = "collection/#{context.collection.id}/artists"
    response = Library.handle_request(context.channel_id, path)
    assert response == %{
      id: "peel:" <> path,
      title: "Artists",
      # icon: artist.cover_image,
      icon: "",
      search: %{title: "artists", url: "peel:search/#{context.collection.id}/artists"},
      children: [
        %{ title: "E",
          id: "peel:artists:E",
          size: "s",
          metadata: nil,
          icon: nil,
          actions: nil,
          length: 1,
          children: [
            %{
              actions: %{ click: %{level: true, url: "peel:artist/ece2ce41-3194-4506-9e16-42e56e1be090"}, play: nil },
              icon: "", title: "Echo and the Bunnymen", metadata: nil},
          ],
        },
        %{ title: "T",
          id: "peel:artists:T",
          size: "s",
          icon: nil,
          metadata: nil,
          actions: nil,
          length: 2,
          children: [
            %{
              actions: %{ click: %{ level: true, url: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e" }, play: nil },
              icon: "", title: "Talking Heads", metadata: nil},
            %{
              actions: %{ click: %{level: true, url: "peel:artist/b408ec33-f533-49f6-944b-5d829139e1de"}, play: nil },
              icon: "", title: "The Lurkers", metadata: nil},
          ],
        },
      ],
    }
  end

  test "peel:artist/{artist_id}", context do
    artist = Artist.find("fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e")
    path = "artist/#{artist.id}"
    response = Library.handle_request(context.channel_id, path)

    assert response == %{
      id: "peel:" <> path,
      title: artist.name,
      # icon: artist.cover_image,
      icon: "",
      search: nil,
      children: [
        %{ title: "Talking Heads: 77",
          size: "l",
          icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
          id: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898",
          metadata: [
            [ %{title: "1977", action: nil} ]
          ],
          actions: %{
            click: %{url: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e/play", level: false},
            play: %{url: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e/play", level: false}
          },
          length: 2,
          children: [
            track_node(Track.find("94499562-d2c5-41f8-b07c-ecfbecf0c428")),
            track_node(Track.find("a3c90ce4-8a98-405f-bffd-04bc744c13df")),
          ]
        },
        %{ title: "Some Compilation",
          id: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
          size: "l",
          icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/1/f/1f74a72a-800d-443e-9bb2-4fc5e10ff43d.jpg",
          metadata: nil,
          length: 1,
          actions: %{
            click: %{url: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e/play", level: false},
            play: %{url: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e/play", level: false}
          },
          children: [
            track_node(Track.find("0a89f07e-0f5e-48c4-8b00-d83026a90724")),
          ]
        },
      ],
    }
  end

  # all tracks by a certain artist in the given album
  # Deprecated
  # test "peel:album/{album_id}/artist/{artist_id}", context do
  #   artist = Artist.find("fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e")
  #   album = Album.find("1f74a72a-800d-443e-9bb2-4fc5e10ff43d")
  #   path = "album/#{album.id}/artist/#{artist.id}"
  #   response = Library.handle_request(context.channel_id, path)
  #
  #   assert response == %{
  #     id: "peel:" <> path,
  #     search: nil,
  #     children: [
  #       %{ title: album.title,
  #         id: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d",
  #         icon: album.cover_image,
  #         metadata: nil,
  #         size: "l",
  #         actions: %{
  #           click: %{url: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e/play", level: false},
  #           play: %{url: "peel:album/1f74a72a-800d-443e-9bb2-4fc5e10ff43d/artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e/play", level: false}
  #         },
  #         children: [
  #           track_node(Track.find("0a89f07e-0f5e-48c4-8b00-d83026a90724")),
  #         ],
  #       }
  #     ]
  #   }
  # end

  test "peel:track/{track_id}/play", %{channel_id: channel_id} = _context do
    track = Track.find("94499562-d2c5-41f8-b07c-ecfbecf0c428")
    path = "track/#{track.id}/play"
    Library.handle_request(channel_id, path)
    assert_receive {:playlist, :append, [^channel_id, [%Otis.State.Rendition{source_id: "94499562-d2c5-41f8-b07c-ecfbecf0c428", source_type: "Elixir.Peel.Track"}]]}
  end

  test "peel:album/{album_id}/play", %{channel_id: channel_id} = _context do
    album = Album.find("7aed1ef3-de88-4ea8-9af7-29a1327a5898")
    path = "album/#{album.id}/play"
    Library.handle_request(channel_id, path)

    assert_receive {:append_renditions, [^channel_id, [
        %Otis.State.Rendition{source_id: "94499562-d2c5-41f8-b07c-ecfbecf0c428", source_type: "Elixir.Peel.Track"},
        %Otis.State.Rendition{source_id: "a3c90ce4-8a98-405f-bffd-04bc744c13df", source_type: "Elixir.Peel.Track"},
      ]
    ]}
  end

  test "search all music", %{channel_id: channel_id} = context do
    artists = [
      %Artist{
        collection_id: context.collection.id,
        id: "fdb8a7b3-e259-4ef3-a453-833f2795dec6", name: "The Big Monkey",
        normalized_name: "the big monkey" },
    ]
    Enum.map artists, &Repo.insert!/1

    albums = [
      %Album{ id: "69eff193-5808-4165-a927-b5431d7da97b",
        collection_id: context.collection.id,
        date: "1977", disk_number: 1, disk_total: 1, genre: "Rock",
        normalized_title: "monkey songs", performer: "Monkey Sings",
        cover_image: "",
        title: "Monkey Songs", track_total: 2 },
      %Album{ id: "8231ab23-0c44-44b1-891c-53917f085d82",
        collection_id: context.collection.id,
        date: nil, disk_number: 1, disk_total: 1, genre: "Rock",
        normalized_title: "dance monkey dance", performer: "Various Artists",
        cover_image: "",
        title: "Dance Monkey Dance", track_total: 3 },
    ]
    tracks = [
      %Peel.Track{ id: "118739fb-4558-4522-987d-bd3c5e805d7a",
        collection_id: context.collection.id,
        album_id: "7aed1ef3-de88-4ea8-9af7-29a1327a5898",
        album_title: "Talking Heads: 77",
        artist_id: "fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", composer: "David Byrne",
        cover_image: "",
        date: "1977", disk_number: 1, disk_total: 1, duration_ms: 159000,
        genre: "Rock", mime_type: "audio/mp4",
        normalized_title: "beware the wild monkey",
        path: "",
        performer: "Talking Heads", title: "Beware the Wild Monkey",
        track_number: 1, track_total: 11},
    ]
    Enum.map albums, &Repo.insert!/1
    Enum.map tracks, &Repo.insert!/1

    path = "search/#{context.collection.id}"
    query = "monkey"
    response = Library.handle_request(channel_id, path, query)
    assert response == %{
      id: "peel:search/#{context.collection.id}",
      title: "Search #{context.collection.name}",
      icon: "",
      search: %{ title: context.collection.name, url: "peel:search/#{context.collection.id}"},
      length: 3,
      children: [
        %{
          title: "Albums",
          id: "peel:search/#{context.collection.id}/albums",
          size: "s",
          icon: nil,
          actions: nil,
          metadata: nil,
          length: 2,
          children: [
            %{ title: "Monkey Songs",
              actions: %{
                click: %{url: "peel:album/69eff193-5808-4165-a927-b5431d7da97b", level: true},
                play:  %{url: "peel:album/69eff193-5808-4165-a927-b5431d7da97b/play", level: false},
              },
              icon: "",
              metadata: [[%{action: nil, title: "Various Artists"}], [%{action: nil, title: "1977"}]],
            },
            %{ title: "Dance Monkey Dance",
              actions: %{
                click: %{url: "peel:album/8231ab23-0c44-44b1-891c-53917f085d82", level: true},
                play:  %{url: "peel:album/8231ab23-0c44-44b1-891c-53917f085d82/play", level: false},
              },
              icon: "",
              metadata: [[%{action: nil, title: "Various Artists"}]],
            },
          ],
        },
        %{
          title: "Artists",
          id: "peel:search/#{context.collection.id}/artists",
          size: "s",
          icon: nil,
          actions: nil,
          metadata: nil,
          length: 1,
          children: [
            %{ actions: %{ click: %{ level: true, url: "peel:artist/fdb8a7b3-e259-4ef3-a453-833f2795dec6" }, play: nil },
              icon: "", title: "The Big Monkey", metadata: nil},
          ],
        },
        %{
          title: "Tracks",
          id: "peel:search/#{context.collection.id}/tracks",
          size: "s",
          icon: nil,
          actions: nil,
          metadata: nil,
          length: 1,
          children: [
            track_node(Track.find("118739fb-4558-4522-987d-bd3c5e805d7a")),
          ],
        },
      ]
    }
  end

  test "search albums", %{channel_id: channel_id} = context do
    path = "search/#{context.collection.id}/albums"
    query = "heads"
    response = Library.handle_request(channel_id, path, query)
    assert response == %{
      id: "peel:search/#{context.collection.id}/albums",
      title: "Search albums",
      icon: "",
      search: %{ title: "albums", url: "peel:search/#{context.collection.id}/albums"},
      length: 1,
      children: [
        %{
          title: "Albums matching ‘heads’",
          id: "peel:search/#{context.collection.id}/albums",
          size: "s",
          icon: nil,
          actions: nil,
          metadata: nil,
          length: 1,
          children: [
              %{ title: "Talking Heads: 77",
                actions: %{
                  click: %{url: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898", level: true},
                  play:  %{url: "peel:album/7aed1ef3-de88-4ea8-9af7-29a1327a5898/play", level: false},
                },
              icon: "/fs/d2e91614-135a-11e6-9170-002500f418fc/cover/7/a/7aed1ef3-de88-4ea8-9af7-29a1327a5898.jpg",
              metadata: [
                [%{title: "Talking Heads", action: %{url: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e", level: true}}],
                [%{title: "1977", action: nil}]
              ],
            },
          ],
        },
      ]
    }
  end

  test "search artists", %{channel_id: channel_id} = context do
    path = "search/#{context.collection.id}/artists"
    query = "talking"
    response = Library.handle_request(channel_id, path, query)
    assert response == %{
      id: "peel:search/#{context.collection.id}/artists",
      title: "Search artists",
      icon: "",
      search: %{ title: "artists", url: "peel:search/#{context.collection.id}/artists"},
      length: 1,
      children: [
        %{
          title: "Artists matching ‘talking’",
          id: "peel:search/#{context.collection.id}/artists",
          size: "s",
          icon: nil,
          actions: nil,
          metadata: nil,
          length: 1,
          children: [
            %{
              actions: %{ click: %{ level: true, url: "peel:artist/fbc1a6eb-57a8-4e85-bda3-e493a21d7f9e" }, play: nil },
              icon: "", title: "Talking Heads", metadata: nil},
          ],
        },
      ]
    }
  end
end
