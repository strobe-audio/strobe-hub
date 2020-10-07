defmodule Peel.Modifications.MoveTest do
  use ExUnit.Case

  alias Peel.Collection
  alias Peel.Track

  @fixtures [__DIR__, "../../fixtures/music"] |> Path.join() |> Path.expand()
  @milkman [
             "01 Milk Man",
             "02 Giga Dance",
             "03 Desaparecere"
           ]
           |> Enum.map(&"Deerhoof/Milk Man/#{&1}.mp3")

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Peel.Repo)
    Collection.delete_all()

    config = Application.get_env(:peel, Peel.Collection)
    File.mkdir_p(config[:root])

    collection = Collection.create("My Music", config[:root])

    on_exit(fn ->
      File.rm_rf(config[:root])
    end)

    TestEventHandler.attach([Peel.WebDAV.Modifications])
    {:ok, root: config[:root], collection: collection}
  end

  def copy(dest, src, %{collection: collection}) do
    copy(dest, src, collection)
  end

  def copy(_path, src, %Collection{} = collection) do
    dest = [collection.path, src] |> Path.join()
    :ok = dest |> Path.dirname() |> File.mkdir_p()
    :ok = File.cp([@fixtures, src] |> Path.join(), dest)
    [Collection.dav_path(collection), src] |> Path.join()
  end

  test "rename collection", cxt do
    new_name = "Other Music"
    evt = {:move, [:directory, "/#{cxt.collection.name}", "/#{new_name}"]}
    Peel.WebDAV.Modifications.notify(evt)
    assert_receive {:complete, ^evt}, 500

    coll = Collection.find(cxt.collection.id)
    assert coll.name == new_name
  end

  test "move single file", cxt do
    [path1] =
      @milkman
      |> Enum.take(1)
      |> Enum.map(fn path ->
        {path, [Collection.dav_path(cxt.collection), path] |> Path.join()}
      end)
      |> Enum.map(fn {fixture_path, dav_path} ->
        copy(dav_path, fixture_path, cxt)
        dav_path
      end)

    Peel.WebDAV.Modifications.notify({:create, [:file, path1]})
    assert_receive {:complete, {:create, [:file, ^path1]}}, 500

    destination = "Queerhoof/Moat Man/01 Moat Man.mp3"
    dest_path = "/My Music/#{destination}"
    Peel.WebDAV.Modifications.notify({:move, [:file, path1, dest_path]})
    assert_receive {:complete, {:move, [:file, ^path1, ^dest_path]}}, 500

    [track] = Track.all()
    assert track.path == destination
  end

  test "move single file between collections", cxt do
    other_collection = Collection.create("Other Music", cxt.root)
    [src_path1] = @milkman |> Enum.take(1)

    [path1] =
      @milkman
      |> Enum.take(1)
      |> Enum.map(fn path ->
        {path, [Collection.dav_path(cxt.collection), path] |> Path.join()}
      end)
      |> Enum.map(fn {fixture_path, dav_path} ->
        copy(dav_path, fixture_path, cxt)
        dav_path
      end)

    Peel.WebDAV.Modifications.notify({:create, [:file, path1]})
    assert_receive {:complete, {:create, [:file, ^path1]}}, 500
    dest_path = [Collection.dav_path(other_collection), src_path1] |> Path.join()

    Peel.WebDAV.Modifications.notify({:move, [:file, path1, dest_path]})
    assert_receive {:complete, {:move, [:file, ^path1, ^dest_path]}}, 500

    [track] = Track.all()
    assert track.path == src_path1
    assert track.collection_id == other_collection.id
  end

  test "move directory", cxt do
    [path1, path2, path3] =
      @milkman
      |> Enum.map(fn path ->
        {path, [Collection.dav_path(cxt.collection), path] |> Path.join()}
      end)
      |> Enum.map(fn {fixture_path, dav_path} ->
        copy(dav_path, fixture_path, cxt)
        dav_path
      end)

    Peel.WebDAV.Modifications.notify({:create, [:file, path1]})
    Peel.WebDAV.Modifications.notify({:create, [:file, path2]})
    Peel.WebDAV.Modifications.notify({:create, [:file, path3]})
    assert_receive {:complete, {:create, [:file, ^path1]}}, 500
    assert_receive {:complete, {:create, [:file, ^path2]}}, 500
    assert_receive {:complete, {:create, [:file, ^path3]}}, 500

    src = ["/My Music", "Deerhoof"] |> Path.join()
    dst = ["/My Music", "Queerhoof"] |> Path.join()
    Peel.WebDAV.Modifications.notify({:move, [:directory, src, dst]})
    assert_receive {:complete, {:move, [:directory, ^src, ^dst]}}, 500
    [track1, track2, track3] = Track.all() |> Enum.sort_by(fn t -> t.path end)
    assert track1.path == "Queerhoof/Milk Man/01 Milk Man.mp3"
    assert track2.path == "Queerhoof/Milk Man/02 Giga Dance.mp3"
    assert track3.path == "Queerhoof/Milk Man/03 Desaparecere.mp3"
  end

  test "move directory between collections", cxt do
    other_collection = Collection.create("Other Music", cxt.root)
    [src_path1, src_path2, src_path3] = @milkman

    [path1, path2, path3] =
      @milkman
      |> Enum.map(fn path ->
        {path, [Collection.dav_path(cxt.collection), path] |> Path.join()}
      end)
      |> Enum.map(fn {fixture_path, dav_path} ->
        copy(dav_path, fixture_path, cxt)
        dav_path
      end)

    Peel.WebDAV.Modifications.notify({:create, [:file, path1]})
    Peel.WebDAV.Modifications.notify({:create, [:file, path2]})
    Peel.WebDAV.Modifications.notify({:create, [:file, path3]})
    assert_receive {:complete, {:create, [:file, ^path1]}}, 500
    assert_receive {:complete, {:create, [:file, ^path2]}}, 500
    assert_receive {:complete, {:create, [:file, ^path3]}}, 500

    Track.all()
    |> Enum.each(fn track ->
      assert track.collection_id == cxt.collection.id
    end)

    src = ["/My Music", "Deerhoof"] |> Path.join()
    dst = ["/Other Music", "Deerhoof"] |> Path.join()
    Peel.WebDAV.Modifications.notify({:move, [:directory, src, dst]})
    assert_receive {:complete, {:move, [:directory, ^src, ^dst]}}, 500
    [track1, track2, track3] = Track.all() |> Enum.sort_by(fn t -> t.path end)
    assert track1.path == src_path1
    assert track2.path == src_path2
    assert track3.path == src_path3

    assert track1.collection_id == other_collection.id
    assert track2.collection_id == other_collection.id
    assert track3.collection_id == other_collection.id
  end
end
