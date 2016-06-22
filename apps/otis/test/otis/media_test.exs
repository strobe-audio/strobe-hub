defmodule Test.Otis.Packet do
  use ExUnit.Case, async: true

  setup do
    tmp = System.tmp_dir!()
    id = System.unique_integer([:positive])
    root = Path.join([tmp, to_string(id)])
    at = "/media"
    contents =
      quote do
        use Otis.Media.Filesystem, root: unquote(root), at: unquote(at)
      end
    fs = Module.concat(FS, "Test#{id}")
    Module.create(fs, contents, Macro.Env.location(__ENV__))

    {:ok, root: root, at: at, fs: fs}
  end

  test "it can return its configured root", context do
    assert context.fs.root() == context.root
  end

  test "it can return its configured http mount point", context do
    assert context.fs.at() == context.at
  end

  test "it can ensure the existance of a file from a path", context do
    id = "peel"
    path = Path.join([context.root, id, "placeholder.jpg"])
    assert File.exists?(path) == false
    {:ok, "/media/peel/placeholder.jpg"} = context.fs.copy(id, "placeholder.jpg", Path.expand("../fixtures/placeholder.jpg", __DIR__))
    assert File.exists?(path) == true
    on_exit fn ->
      if File.exists?(path) do
        File.rm(path)
      end
    end
  end

  test "it can ensure the existance of a file from a path with a compound namespace", context do
    id = "peel"
    path = Path.join([context.root, id, "cover", "placeholder.jpg"])
    assert File.exists?(path) == false
    {:ok, "/media/peel/cover/placeholder.jpg"} = context.fs.copy([id, "cover"], "placeholder.jpg", Path.expand("../fixtures/placeholder.jpg", __DIR__))
    assert File.exists?(path) == true
    on_exit fn ->
      if File.exists?(path) do
        File.rm(path)
      end
    end
  end

  test "path & url generation", context do
    id = "peel"
    assert context.fs.location(id, "6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg") == {:ok, Path.join([context.root, id, "6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"]), "/media/peel/6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"}
    assert File.exists?(Path.join([context.root, id]))
  end

  test "optimized path & url generation (true)", context do
    id = "peel"
    {:ok, path, url} = context.fs.location(id, "6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg", optimize: true)
    assert path == Path.join([context.root, "peel/6/6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"])
    assert url == "/media/peel/6/6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"
    assert File.exists?(Path.join([context.root, id, "6"]))
  end

  test "optimized path & url generation (1)", context do
    id = "peel"
    {:ok, path, url} = context.fs.location(id, "6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg", optimize: 1)
    assert path == Path.join([context.root, "peel/6/6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"])
    assert url == "/media/peel/6/6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"
    assert File.exists?(Path.join([context.root, id, "6"]))
  end

  test "optimized path & url generation (2)", context do
    id = "peel"
    {:ok, path, url} = context.fs.location(id, "6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg", optimize: 2)
    assert path == Path.join([context.root, "peel/6/5/6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"])
    assert url == "/media/peel/6/5/6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"
    assert File.exists?(Path.join([context.root, id, "6", "5"]))
  end

  test "optimized path & url generation (3)", context do
    id = "peel"
    {:ok, path, url} = context.fs.location(id, "6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg", optimize: 3)
    assert path == Path.join([context.root, "peel/6/5/8/6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"])
    assert url == "/media/peel/6/5/8/6587689f-107b-48b7-9fc1-2f21ce6c8c7d.jpg"
    assert File.exists?(Path.join([context.root, id, "6", "5", "8"]))
  end
end

