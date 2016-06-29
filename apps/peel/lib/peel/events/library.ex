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
    Otis.State.Events.notify({:add_library, %{id: Peel.library_id, title: "Your Music", icon: "", action: url("root"), metadata: nil}, socket})
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
        %{ id: "peel:albums", title: "Albums", icon: "", action: url("albums"), metadata: nil },
        %{ id: "peel:artists", title: "Artists", icon: "", action: url("artists"), metadata: nil },
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
        action: action(album)
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
            action: action(track),
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
        action: action(artist),
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
            action: "#{action(album)}/artist/#{artist_id}",
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
            action: action(track),
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

  def album_metadata(_album, [artist]) do
    [ [link(artist.name, action(artist))] ]
  end
  def album_metadata(_album, _artists) do
    [ [link("Various Artists", nil)] ]
  end

  def link(%Track{title: title} = track) do
    link title, action(track)
  end

  def link(%Album{title: title} = album) do
    link title, action(album)
  end

  def link(%Artist{name: name} = artist) do
    link name, action(artist)
  end

  def link(_) do
    link("", nil)
  end

  def link(title, action) do
    %{title: title, action: action}
  end

  def action(%Track{id: id}) do
    url "track/#{id}"
  end

  def action(%Album{id: id}) do
    url "album/#{id}"
  end

  def action(%Artist{id: id}) do
    url "artist/#{id}"
  end

  def url(path) do
    "#{@namespace}#{path}"
  end
end
