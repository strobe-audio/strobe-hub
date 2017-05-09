defmodule Peel.Modifications.CreateTest do
  use ExUnit.Case

  alias Peel.Track
  alias Peel.Album
  alias Peel.Artist

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Peel.Repo)
    TestEventHandler.attach([Peel.Webdav.Modifications])
    :ok
  end

  @fixtures [__DIR__, "../../fixtures/music"] |> Path.join |> Path.expand
  @milkman  [
    "01 Milk Man",
    "02 Giga Dance",
    "03 Desapareceré",
  ] |> Enum.map(&Path.join([@fixtures, "Deerhoof/Milk Man/#{&1}.mp3"]))

  test "create track with new artist & album" do
    [path|_] = @milkman
    Peel.Webdav.Modifications.notify({:create, [path]})
    assert_receive {:complete, {:create, [^path]}}, 500
    assert  length(Track.all) == 1
    [track] = Track.all
    assert track.title == "Milk Man"
    assert track.album_title == "Milk Man"
    assert track.composer == "Deerhoof"
    assert track.date == "2004"
    assert track.genre == "Indie Rock"
    assert track.performer == "Deerhoof"
    assert track.disk_number == 1
    assert track.disk_total == 1
    assert track.track_number == 1
    assert track.normalized_title == "milk man"

    assert  length(Album.all) == 1
    album = Track.album(track)

    assert album.title == "Milk Man"
    assert album.performer == "Deerhoof"
    assert album.date == "2004"
    assert album.genre == "Indie Rock"
    assert album.normalized_title == "milk man"

    assert  length(Artist.all) == 1
    artist = Track.artist(track)

    assert artist.name == "Deerhoof"
    assert artist.normalized_name == "deerhoof"
  end

  test "create track with existing artist & album" do
    [path|_] = @milkman
    Peel.Webdav.Modifications.notify({:create, [path]})
    assert_receive {:complete, {:create, [^path]}}, 500

    [_, path, _] = @milkman
    Peel.Webdav.Modifications.notify({:create, [path]})
    assert_receive {:complete, {:create, [^path]}}, 500

    assert  length(Track.all) == 2
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1

    [_, _, path] = @milkman
    Peel.Webdav.Modifications.notify({:create, [path]})
    assert_receive {:complete, {:create, [^path]}}, 500
    assert  length(Track.all) == 3
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1
  end
end
