
defmodule Peel.Test.CollectionTest do
  use   ExUnit.Case
  alias Peel.Collection

  setup do

    tmp_root =
      [System.tmp_dir!, DateTime.utc_now |> DateTime.to_unix |> to_string]
      |> Path.join

    env =
      [ root: "#{tmp_root}/collection",
        port: 8080
      ]

    # Application.put_env(:peel, Peel.Collection, env)

    on_exit fn ->
      File.rm_rf(tmp_root)
    end

    {:ok, root: tmp_root, env: env}
  end

  test "collection is given a random UUID", cxt do
    coll = Collection.create("My Music", cxt.root)
    assert coll.id != ""
  end

  test "collection is given the correct path", cxt do
    coll = Collection.create("My Music", cxt.root)
    assert coll.path == [cxt.root, coll.name] |> Path.join
  end

  test "dav_path returns an absolute path", _cxt do
    id = Ecto.UUID.generate
    coll = %Collection{id: id, name: "Something"}
    assert Collection.dav_path(coll) == "/#{coll.name}"
  end

  test "renaming updates root path", cxt do
    coll = Collection.create("My Music", cxt.root)
    assert coll.path == [cxt.root, coll.name] |> Path.join
    {:ok, coll} = Collection.rename(coll, "Something Else")
    assert coll.path == [cxt.root, coll.name] |> Path.join
  end
end
