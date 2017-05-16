
defmodule Peel.Test.CoverArtTest do
  use   ExUnit.Case

  alias Peel.Album
  alias Peel.Track
  alias Peel.Repo

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Peel.Repo)
    album = %Album{} |> Repo.insert!
    tracks = Enum.map 1..3, fn(n) ->
      Ecto.build_assoc(album, :tracks, title: "Track #{n+1}") |> Repo.insert!
    end
    {:ok, album: album, tracks: tracks}
  end

  test "it can find albums with no cover image", context do
    assert Peel.CoverArt.pending_albums == [context.album]
  end

  test "it sets the cover image column of the album", context do
    Album.set_cover_image(context.album, "/peel/album/#{context.album.id}.jpg")
    album = Album.find(context.album.id)
    assert album.cover_image == "/peel/album/#{context.album.id}.jpg"
  end

  test "it sets the cover image of all associated tracks", context do
    Album.set_cover_image(context.album, "/peel/album/#{context.album.id}.jpg")
    Enum.each context.tracks, fn(track) ->
      assert Track.find(track.id).cover_image == "/peel/album/#{context.album.id}.jpg"
    end
  end
end
