defmodule Peel.Modifications.CreateTest do
  use ExUnit.Case

  alias Peel.Track
  alias Peel.Album
  alias Peel.Artist
  alias Peel.Collection

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Peel.Repo)
    Collection.delete_all

    config = Application.get_env :peel, Peel.Collection
    File.mkdir_p(config[:root])

    collection = Collection.create("My Music", config[:root])

    on_exit fn ->
      File.rm_rf(config[:root])
    end

    TestEventHandler.attach([Peel.WebDAV.Modifications])
    {:ok, root: config[:root], collection: collection}
  end

  @fixtures [__DIR__, "../../fixtures/music"] |> Path.join |> Path.expand

  @milkman  [
    "01 Milk Man",
    "02 Giga Dance",
    "03 Desaparecere",
  ] |> Enum.map(&"Deerhoof/Milk Man/#{&1}.mp3")

  def dav_path(path, %{collection: collection}) do
    dav_path(path, collection)
  end
  def dav_path(path, %Collection{} = collection) do
    [collection.path, path] |> Path.join
  end

  def copy(dest, src, %{collection: collection}) do
    copy(dest, src, collection)
  end
  def copy(_path, src, %Collection{} = collection) do
    dest = [collection.path, src] |> Path.join
    :ok = dest |> Path.dirname |> File.mkdir_p
    :ok = File.cp([@fixtures, src] |> Path.join, dest)
    [Collection.dav_path(collection), src] |> Path.join
  end

  test "create new collection" do
    name = "New Collection"
    assert length(Collection.all) == 1
    Peel.WebDAV.Modifications.notify({:create, [:collection, name]})
    assert_receive {:complete, {:create, [:collection, ^name]}}, 500
    assert length(Collection.all) == 2
    {:ok, collection} = Collection.from_name(name)
    assert collection.name == name
  end

  test "create track with new artist & album", cxt do
    [path|_] = @milkman
    dav_path = dav_path(path, cxt) |> copy(path, cxt)

    Peel.WebDAV.Modifications.notify({:create, [:file, dav_path]})
    assert_receive {:complete, {:create, [:file, ^dav_path]}}, 500
    assert  length(Track.all) == 1
    [track] = Track.all
    assert track.collection_id == cxt.collection.id
    assert track.path == path
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

    assert album.collection_id == cxt.collection.id
    assert album.title == "Milk Man"
    assert album.performer == "Deerhoof"
    assert album.date == "2004"
    assert album.genre == "Indie Rock"
    assert album.normalized_title == "milk man"

    assert  length(Artist.all) == 1
    artist = Track.artist(track)

    assert artist.collection_id == cxt.collection.id
    assert artist.name == "Deerhoof"
    assert artist.normalized_name == "deerhoof"
  end

  test "create track with existing artist & album", cxt do
    [path|_] = @milkman
    dav_path = dav_path(path, cxt) |> copy(path, cxt)
    Peel.WebDAV.Modifications.notify({:create, [:file, dav_path]})
    assert_receive {:complete, {:create, [:file, ^dav_path]}}, 500

    [_, path, _] = @milkman
    dav_path = dav_path(path, cxt) |> copy(path, cxt)
    Peel.WebDAV.Modifications.notify({:create, [:file, dav_path]})
    assert_receive {:complete, {:create, [:file, ^dav_path]}}, 500

    assert  length(Track.all) == 2
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1

    [_, _, path] = @milkman
    dav_path = dav_path(path, cxt) |> copy(path, cxt)
    Peel.WebDAV.Modifications.notify({:create, [:file, dav_path]})
    assert_receive {:complete, {:create, [:file, ^dav_path]}}, 500
    assert  length(Track.all) == 3
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1
  end
end
