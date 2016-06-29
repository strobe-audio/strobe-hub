defmodule Peel.Events.Library do
  use     GenEvent
  require Logger

  alias Peel.Album
  alias Peel.Artist
  alias Peel.Track

  @namespace "peel:"

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:controller_join, socket}, state) do
    # TODO: icon
    Otis.State.Events.notify({:add_library, %{id: Peel.library_id, title: "Your Music", icon: "", actions: %{ click: url("root"), play: nil }, metadata: nil}, socket})
    {:ok, state}
  end

  def handle_event({:library_request, channel_id, @namespace <> route, socket}, state) do
    case route_library_request(channel_id, route) do
      nil ->
        nil
      response ->
        # IO.inspect {:peel, :library, response}
        Otis.State.Events.notify({:library_response, "peel", response, socket})
    end
    {:ok, state}
  end


  def handle_event(_event, state) do
    {:ok, state}
  end

  def route_library_request(channel_id, route) when is_binary(route) do
    route_library_request(channel_id, String.split(route, "/", trim: true), route)
  end

  def route_library_request(channel_id, ["track", track_id], _path) do
    {:ok, channel} = Otis.Channels.find(channel_id)
    case Track.find(track_id) do
      nil ->
        nil
      track ->
        Otis.Channel.append(channel, track)
        nil
    end
  end

  def route_library_request(_channel_id, ["root"], _path) do
    %{
      id: "peel:root",
      title: "Your Music",
      icon: "",
      children: [
        %{ id: "peel:albums", title: "Albums", icon: "", actions: %{ click: url("albums"), play: nil }, metadata: nil },
        %{ id: "peel:artists", title: "Artists", icon: "", actions: %{ click: url("artists"), play: nil }, metadata: nil },
        # TODO: other top-level items
      ],
    }
  end

  def route_library_request(_channel_id, ["albums"], path) do
    albums = Album.all |> Enum.map(fn(album) ->
      %{
        id: "peel:album/#{album.id}",
        title: album.title,
        metadata: node_metadata(album),
        icon: album.cover_image,
        actions: %{
          click: click_action(album),
          play: play_action(album),
        },
      }
    end)
    %{
      id: path,
      title: "Albums",
      icon: "",
      children: albums
    }
  end

  def route_library_request(_channel_id, ["album", album_id], path) do
    case Album.find(album_id) do
      nil ->
        nil
      album ->
        tracks = album |> Album.tracks |> Enum.map(fn(track) ->
          %{
            id: "peel:track/#{track.id}",
            title: track.title,
            icon: track.cover_image,
            actions: %{
              click: click_action(track),
              play: play_action(track)
            },
            metadata: nil,
          }
        end)
        %{
          id: path,
          title: album.title,
          icon: album.cover_image,
          children: tracks
        }
    end
  end

  def route_library_request(_channel_id, ["artists"], path) do
    artists = Artist.all |> Enum.map(fn(artist) ->
      %{
        id: "peel:artist/#{artist.id}",
        title: artist.name,
        icon: "",
        actions: %{ click: click_action(artist), play: nil },
        metadata: nil,
      }
    end)
    %{
      id: path,
      title: "Artists",
      icon: "",
      children: artists
    }
  end

  def route_library_request(_channel_id, ["artist", artist_id], path) do
    case Artist.find(artist_id) do
      nil ->
        nil
      artist ->
        albums = artist |> Artist.albums |> Enum.map(fn(album) ->
          %{
            id: "peel:album/#{album.id}",
            title: album.title,
            icon: album.cover_image,
            actions: %{
              click: "#{click_action(album)}/artist/#{artist_id}",
              play: "#{click_action(album)}/artist/#{artist_id}/play",
            },
            metadata: nil,
          }
        end)
        %{
          id: path,
          title: artist.name,
          icon: "",
          children: albums
        }
    end
  end

  def route_library_request(_channel_id, ["album", album_id, "artist", artist_id], path) do
    case Album.find(album_id) do
      nil ->
        nil
      album ->
        tracks = Track.album_by_artist(album_id, artist_id)
        children = Enum.map(tracks, fn(track) ->
          %{
            id: "peel:track/#{track.id}",
            title: track.title,
            icon: track.cover_image,
            actions: %{
              click: click_action(track),
              play: play_action(track)
            },
            metadata: nil,
          }
        end)
        %{
          id: path,
          title: album.title,
          icon: album.cover_image,
          children: children
        }
    end
  end

  def route_library_request(_channel_id, _route, path) do
    Logger.warn "Invalid path #{path}"
    nil
  end

  def node_metadata(%Album{} = album) do
    album_metadata(album, Album.artists(album))
  end

  def album_metadata(album, [artist]) do
    [ [link(artist)] ] |> album_date_metadata(album.date)
  end
  def album_metadata(album, _artists) do
    [ [link("Various Artists", nil)] ] |> album_date_metadata(album.date)
  end

  def album_date_metadata(metadata, nil) do
    metadata
  end
  def album_date_metadata(metadata, date) do
    # TODO: add action for searching by date
    metadata ++ [[ link(date, nil) ]]
  end

  def link(%Track{title: title} = track) do
    link title, click_action(track)
  end

  def link(%Album{title: title} = album) do
    link title, click_action(album)
  end

  def link(%Artist{name: name} = artist) do
    link name, click_action(artist)
  end

  def link(_) do
    link("", nil)
  end

  def link(title, action) do
    %{title: title, action: action}
  end

  def click_action(%Track{id: id}) do
    url "track/#{id}"
  end

  def click_action(%Album{id: id}) do
    url "album/#{id}"
  end

  def click_action(%Artist{id: id}) do
    url "artist/#{id}"
  end

  def play_action(%Track{id: id}) do
    url "track/#{id}"
  end

  def play_action(%Album{id: id}) do
    url "album/#{id}/play"
  end

  def play_action(%Artist{id: id}) do
    url "artist/#{id}/play"
  end

  def url(path) do
    "#{@namespace}#{path}"
  end
end
