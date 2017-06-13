defmodule Peel.Modifications.DeleteTest do
  use ExUnit.Case

  alias Peel.Collection
  alias Peel.Track
  alias Peel.Album
  alias Peel.Artist
  alias Peel.AlbumArtist

  @fixtures [__DIR__, "../../fixtures/music"] |> Path.join |> Path.expand
  @milkman  [
    "01 Milk Man",
    "02 Giga Dance",
    "03 Desaparecere",
  ] |> Enum.map(&"Deerhoof/Milk Man/#{&1}.mp3")

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

  def copy(dest, src, %{collection: collection}) do
    copy(dest, src, collection)
  end
  def copy(_path, src, %Collection{} = collection) do
    dest = [collection.path, src] |> Path.join
    :ok = dest |> Path.dirname |> File.mkdir_p
    :ok = File.cp([@fixtures, src] |> Path.join, dest)
    [Collection.dav_path(collection), src] |> Path.join
  end

  test "delete single file", cxt do
    [path1, path2, _] =
      Enum.map(@milkman, fn(path) ->
        {path, [Collection.dav_path(cxt.collection), path] |> Path.join}
      end)
      |> Enum.map(fn({fixture_path, dav_path}) ->
        copy(dav_path, fixture_path, cxt)
        dav_path
      end)
    Peel.WebDAV.Modifications.notify({:create, [:file, path1]})
    Peel.WebDAV.Modifications.notify({:create, [:file, path2]})
    assert_receive {:complete, {:create, [:file, ^path1]}}, 500
    assert_receive {:complete, {:create, [:file, ^path2]}}, 500

    assert  length(Track.all) == 2
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1
    assert  length(AlbumArtist.all) == 1
    Peel.WebDAV.Modifications.notify({:delete, [:file, path1]})
    assert_receive {:complete, {:delete, [:file, ^path1]}}, 500
    assert  length(Track.all) == 1
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1
    assert  length(AlbumArtist.all) == 1
    [track] = Track.all
    assert track.title == "Giga Dance"
  end

  test "delete all tracks for album", cxt do
    [path1, _, _] =
      Enum.map(@milkman, fn(path) ->
        {path, [Collection.dav_path(cxt.collection), path] |> Path.join}
      end)
      |> Enum.map(fn({fixture_path, dav_path}) ->
        copy(dav_path, fixture_path, cxt)
        dav_path
      end)
    Peel.WebDAV.Modifications.notify({:create, [:file, path1]})
    assert_receive {:complete, {:create, [:file, ^path1]}}, 500
    assert  length(Track.all) == 1
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1
    Peel.WebDAV.Modifications.notify({:delete, [:file, path1]})
    assert_receive {:complete, {:delete, [:file, ^path1]}}, 500
    assert  length(Track.all) == 0
    assert  length(AlbumArtist.all) == 0
    assert  length(Album.all) == 0
    assert  length(Artist.all) == 0
  end

  test "delete directory", cxt do
    [path1, path2, path3] =
      Enum.map(@milkman, fn(path) ->
        {path, [Collection.dav_path(cxt.collection), path] |> Path.join}
      end)
      |> Enum.map(fn({fixture_path, dav_path}) ->
        copy(dav_path, fixture_path, cxt)
        dav_path
      end)
    Peel.WebDAV.Modifications.notify({:create, [:file, path1]})
    Peel.WebDAV.Modifications.notify({:create, [:file, path2]})
    Peel.WebDAV.Modifications.notify({:create, [:file, path3]})
    assert_receive {:complete, {:create, [:file, ^path1]}}, 500
    assert  length(Track.all) == 3
    assert  length(Album.all) == 1
    assert  length(Artist.all) == 1
    dir = Path.dirname(path1)
    Peel.WebDAV.Modifications.notify({:delete, [:directory, dir]})
    assert_receive {:complete, {:delete, [:directory, ^dir]}}, 500
    assert  length(Track.all) == 0
    assert  length(AlbumArtist.all) == 0
    assert  length(Album.all) == 0
    assert  length(Artist.all) == 0
  end

  test "delete collection", cxt do
    path = "/#{cxt.collection.name}"
    sub_path = "#{path}/sub"
    :ok = [cxt.root, sub_path] |> Path.join |> Path.dirname |> File.mkdir_p
    assert length(Collection.all) == 1
    _track = Track.new("#{sub_path}/Track.mp3", cxt.collection, %{}) |> Peel.Repo.insert!
    assert length(Track.all) == 1
    Peel.WebDAV.Modifications.notify({:delete, [:directory, sub_path]})
    assert_receive {:complete, {:delete, [:directory, ^sub_path]}}, 500
    assert length(Collection.all) == 1
    Peel.WebDAV.Modifications.notify({:delete, [:directory, path]})
    assert_receive {:complete, {:delete, [:directory, ^path]}}, 500
    assert length(Collection.all) == 0
    assert length(Track.all) == 0
  end
end
