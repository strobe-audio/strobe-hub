defmodule Peel.Events.Library do
  use     GenEvent
  require Logger

  alias Peel.Album
  alias Peel.Artist
  alias Peel.Track

  use  Otis.Library, namespace: "peel"

  def event_handler do
    {__MODULE__, []}
  end

  def setup(state) do
    # Copy my placeholder here
    state
  end

  def library do
    %{ id: Peel.library_id,
      title: "Your Music",
      icon: "",
      size: "m",
      actions: %{
        click: %{ url: url("root"), level: true },
        play: nil,
      },
      metadata: nil,
      children: [],
      length: 0,
    }
  end

  def route_library_request(channel_id, ["track", track_id, "play"], _query, _path) do Track.find(track_id) |> play(channel_id)
  end
  def route_library_request(channel_id, ["track", track_id], _query, _path) do
    Track.find(track_id) |> play(channel_id)
  end


  def route_library_request(_channel_id, ["root"], _query, _path) do
    %{
      id: "peel:root",
      title: "Your Music",
      icon: "",
      search: %{url: search_url("root"), title: "your music" },
      length: 2,
      children: [
        section(%{ id: "peel:albums", title: "Albums", size: "m", icon: "", actions: %{ click: %{ url: url("albums"), level: true }, play: nil }, metadata: nil, children: [] }),
        section(%{ id: "peel:artists", title: "Artists", size: "m", icon: "", actions: %{ click: %{ url: url("artists"), level: true }, play: nil }, metadata: nil, children: [] }),
      ],
    }
  end

  def route_library_request(_channel_id, ["albums"], _query, path) do
    albums =
      Album.sorted
      |> Enum.map(&folder_node/1)
      |> Enum.group_by(&alphabetical_section/1)
      |> Enum.map(&album_section/1)
      |> Enum.sort_by(fn(s) -> s.title end)
    %{
      id: namespaced(path),
      title: "Albums",
      icon: "",
      search: %{url: search_url("albums"), title: "albums" },
      children: albums
    }
  end

  def route_library_request(_channel_id, ["album", album_id], _query, path) do
    case Album.find(album_id) do
      nil -> nil
      album ->
        tracks = album |> Album.tracks |> Enum.map(&folder_node/1)
        section = %{
          id: namespaced(path),
          title: album.title,
          actions: %{ click: play_action(album), play: play_action(album) },
          size: "h",
          icon: album.cover_image,
          metadata: node_metadata(album),
          children: tracks
        } |> section()
        %{
          id: namespaced(path),
          title: album.title,
          icon: icon(album.cover_image),
          search: nil,
          children: [section],
        }
    end
  end

  def route_library_request(channel_id, ["album", album_id, "play"], _query, _path) do
    case Album.find(album_id) do
      nil ->
        nil
      album ->
        Album.tracks(album) |> play(channel_id)
    end
  end

  def route_library_request(_channel_id, ["artists"], _query, path) do
    artists =
      Artist.sorted
      |> Enum.map(&folder_node/1)
      |> Enum.group_by(&alphabetical_section/1)
      |> Enum.map(&artist_section/1)
      |> Enum.sort_by(fn(s) -> s.title end)
    %{
      id: namespaced(path),
      title: "Artists",
      icon: "",
      search: %{url: search_url("artists"), title: "artists" },
      children: artists
    }
  end

  def route_library_request(_channel_id, ["artist", artist_id], _query, path) do
    case Artist.find(artist_id) do
      nil -> nil
      artist ->
        albums = artist |> Artist.albums |> Enum.map(fn(album) ->
          tracks = Track.album_by_artist(album.id, artist_id)
          click = click_action(album)
          %{
            id: "peel:album/#{album.id}",
            title: album.title,
            icon: icon(album.cover_image),
            size: "l",
            actions: %{
              click: %{ url: "#{click.url}/artist/#{artist_id}/play", level: false},
              play: %{ url: "#{click.url}/artist/#{artist_id}/play", level: false},
            },
            metadata: album_date_metadata([], album.date),
            children: Enum.map(tracks, &folder_node/1)
          } |> section()
        end)

        %{
          id: namespaced(path),
          title: artist.name,
          icon: "",
          search: nil,
          children: albums,
        }
    end
  end

  # deprecated
  def route_library_request(_channel_id, ["album", album_id, "artist", artist_id], _query, path) do
    case Album.find(album_id) do
      nil -> nil
      album ->
        tracks = Track.album_by_artist(album_id, artist_id)
        children = Enum.map(tracks, fn(track) ->
          %{
            id: "peel:track/#{track.id}",
            title: track.title,
            icon: icon(track.cover_image),
            actions: %{
              click: click_action(track),
              play: play_action(track)
            },
            metadata: [
              [%{title: Peel.Duration.hms_ms(track.duration_ms), action: nil}],
            ],
          }
        end)
        %{
          id: namespaced(path),
          title: album.title,
          icon: icon(album.cover_image),
          search: nil,
          children: children
        }
    end
  end

  def route_library_request(channel_id, ["album", album_id, "artist", artist_id, "play"], _query, _path) do
    case Album.find(album_id) do
      nil ->
        nil
      _album ->
        tracks = Track.album_by_artist(album_id, artist_id)
        play(tracks, channel_id)
    end
  end

  def route_library_request(_channel_id, ["search", "root"], query, path) do
    [artists, albums, tracks] =
      [Artist, Album, Track]
      |> Enum.map(&search_model(&1, query))
    albums_section = %{
      id: namespaced("search/albums"),
      title: "Albums",
      size: "s",
      children: albums,
    } |> section()
    artists_section = %{
      id: namespaced("search/artists"),
      title: "Artists",
      size: "s",
      children: artists,
    } |> section()
    tracks_section = %{
      id: namespaced("search/tracks"),
      title: "Tracks",
      size: "s",
      children: tracks,
    } |> section()
    %{
      id: namespaced(path),
      title: "Search your music",
      icon: icon(nil),
      search: nil,
      search: %{url: search_url("root"), title: "your music" },
      length: 3,
      children: [
        albums_section,
        artists_section,
        tracks_section,
      ],
    }
  end
  def route_library_request(_channel_id, ["search", "albums"], query, path) do
    albums = query |> Peel.Album.search |> Enum.map(&folder_node/1)
    albums_section = %{
      id: namespaced("search/albums"),
      title: "Albums matching ‘#{query}’",
      size: "s",
      children: albums,
    } |> section()
    %{
      id: namespaced(path),
      title: "Search albums",
      icon: icon(nil),
      search: %{url: search_url("albums"), title: "albums" },
      length: 1,
      children: [albums_section],
    }
  end
  def route_library_request(_channel_id, ["search", "artists"], query, path) do
    artists = query |> Peel.Artist.search |> Enum.map(&folder_node/1)
    artists_section = %{
      id: namespaced("search/artists"),
      title: "Artists matching ‘#{query}’",
      size: "s",
      children: artists,
    } |> section()
    %{
      id: namespaced(path),
      title: "Search artists",
      icon: icon(nil),
      search: %{url: search_url("artists"), title: "artists" },
      length: 1,
      children: [artists_section],
    }
  end
  def route_library_request(_channel_id, ["search", category], _query, _path) do
    Logger.warn "Searching uknown category #{inspect category}"
    nil
  end

  def route_library_request(_channel_id, _route, path) do
    Logger.warn "Invalid path #{path}"
    nil
  end

  def search_model(model, query) do
    query
    |> model.search()
    |> Enum.map(&folder_node/1)
  end

  def node_metadata(%Album{} = album) do
    album_metadata(album, Album.artists(album))
  end

  def album_metadata(_album, nil) do
  end
  def album_metadata(album, [artist]) do
    [ [link(artist)] ] |> album_date_metadata(album.date)
  end
  def album_metadata(album, _artists) do
    [ [link("Various Artists", nil)] ] |> album_date_metadata(album.date)
  end

  def album_date_metadata([], nil) do
    nil
  end
  def album_date_metadata(metadata, nil) do
    metadata
  end
  def album_date_metadata(metadata, date) do
    # TODO: add action for searching by date
    metadata ++ [[ library_link(date, nil) ]]
  end

  def link(%Track{title: title} = track) do
    library_link title, click_action(track)
  end
  def link(%Album{title: title} = album) do
    library_link title, click_action(album)
  end
  def link(%Artist{name: name} = artist) do
    library_link name, click_action(artist)
  end
  def link(_) do
    library_link("", nil)
  end

  def link(title, action) when is_binary(title) do
    library_link(title, action)
  end

  def click_action(%Track{id: id}) do
    %{ url: url(["track", id, "play"]), level: false }
  end

  def click_action(%Album{id: id}) do
    %{ url: url(["album", id]), level: true }
  end

  def click_action(%Artist{id: id}) do
    %{ url: url(["artist", id]), level: true }
  end

  def play_action(%Track{id: id}) do
    %{ url: url(["track", id, "play"]), level: false }
  end

  def play_action(%Album{id: id}) do
    %{ url: url(["album", id, "play"]), level: false }
  end

  def play_action(%Artist{id: id}) do
    %{ url: url(["artist", id, "play"]), level: false }
  end

  def icon(nil), do: ""
  def icon(icon), do: icon

  def search_url(category) do
    url(["search", category])
  end

  def folder_node(%Artist{} = artist) do
    %{
      # id: "peel:artist/#{artist.id}",
      title: artist.name,
      icon: "",
      actions: %{ click: click_action(artist), play: nil },
      metadata: nil,
    }
  end
  def folder_node(%Album{} = album) do
    %{
      # id: "peel:album/#{album.id}",
      title: album.title,
      metadata: node_metadata(album),
      icon: icon(album.cover_image),
      actions: %{
        click: click_action(album),
        play: play_action(album),
      },
    }
  end

  def folder_node(%Track{} = track) do
    %{
      # id: "peel:track/#{track.id}",
      title: track.title,
      icon: nil, # icon(track.cover_image),
      actions: %{
        click: click_action(track),
        play: play_action(track)
      },
      metadata: [
        [%{title: Peel.Duration.hms_ms(track.duration_ms), action: nil}],
      ],
    }
  end

  def alphabetical_section(element, field \\ :title) do
    Map.get(element, field, "") |> String.first |> String.upcase |> grouped_alphabetical
  end

  @letters 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

  def grouped_alphabetical(<<l::utf8>>) when l in @letters do
    <<l::utf8>>
  end
  def grouped_alphabetical(_l) do
    "#"
  end

  def album_section({letter, children}) do
    %{ id: namespaced("albums:#{letter}"), title: letter, children: children } |> section
  end

  def artist_section({letter, children}) do
    %{ id: namespaced("artists:#{letter}"), title: letter, children: children } |> section
  end
end
