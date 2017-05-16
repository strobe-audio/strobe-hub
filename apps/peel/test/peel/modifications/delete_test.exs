defmodule Peel.Modifications.DeleteTest do
  use ExUnit.Case

  alias Peel.Track
  alias Peel.Album
  alias Peel.Artist
  alias Peel.AlbumArtist

  @fixtures [__DIR__, "../../fixtures/music"] |> Path.join |> Path.expand
  @milkman  [
    "01 Milk Man",
    "02 Giga Dance",
    "03 Desaparecere",
  ] |> Enum.map(&Path.join([@fixtures, "Deerhoof/Milk Man/#{&1}.mp3"]))

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Peel.Repo)
    TestEventHandler.attach([Peel.Webdav.Modifications])
    :ok
  end

  test "delete single file" do
    [path1, path2, _] = @milkman
    Peel.Webdav.Modifications.notify({:create, [path1]})
    Peel.Webdav.Modifications.notify({:create, [path2]})
    assert_receive {:complete, {:create, [^path1]}}, 500
    assert_receive {:complete, {:create, [^path2]}}, 500

    assert  length(Track.all) == 2
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1
    assert  length(AlbumArtist.all) == 1
    Peel.Webdav.Modifications.notify({:delete, [path1]})
    assert_receive {:complete, {:delete, [^path1]}}, 500
    assert  length(Track.all) == 1
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1
    assert  length(AlbumArtist.all) == 1
    [track] = Track.all
    assert track.title == "Giga Dance"
  end

  test "delete all tracks for album" do
    [path1, _, _] = @milkman
    Peel.Webdav.Modifications.notify({:create, [path1]})
    assert_receive {:complete, {:create, [^path1]}}, 500
    assert  length(Track.all) == 1
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1
    Peel.Webdav.Modifications.notify({:delete, [path1]})
    assert_receive {:complete, {:delete, [^path1]}}, 500
    assert  length(Track.all) == 0
    assert  length(AlbumArtist.all) == 0
    assert  length(Album.all) == 0
    assert  length(Artist.all) == 0
  end
end
