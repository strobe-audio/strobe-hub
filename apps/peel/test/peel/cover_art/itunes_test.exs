defmodule Peel.CoverArt.ITunesTest do
  use ExUnit.Case

  alias Peel.CoverArt.ITunes.Album

  describe "Album" do
    setup do
      album = %Album{
        artworkUrl100:
          "http://is1.mzstatic.com/image/thumb/Music111/v4/7d/c4/be/7dc4be2f-eacc-cddb-e748-0ee382627d9c/source/100x100bb.jpg",
        artworkUrl60:
          "http://is1.mzstatic.com/image/thumb/Music111/v4/7d/c4/be/7dc4be2f-eacc-cddb-e748-0ee382627d9c/source/60x60bb.jpg",
        collectionId: 1_221_702_805,
        collectionName: "Peasant",
        collectionViewUrl: "https://itunes.apple.com/us/album/peasant/id1221702805?uo=4"
      }

      {:ok, album: album}
    end

    test "arbitrary sized cover image", cxt do
      assert Album.cover_art(cxt.album, 500, 500) ==
               "http://is1.mzstatic.com/image/thumb/Music111/v4/7d/c4/be/7dc4be2f-eacc-cddb-e748-0ee382627d9c/source/500x500bb.jpg"
    end
  end
end
