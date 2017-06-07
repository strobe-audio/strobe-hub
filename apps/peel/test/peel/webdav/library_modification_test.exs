defmodule Peel.WebDAV.LibraryModificationTest do
  use   ExUnit.Case

  alias Peel.WebDAV.LibraryModification, as: M

  defmodule MockTester do
    # assume that all paths in this test will be files, not directories
    def is_file?(_path), do: true
  end

  def new(depth) do
    M.new("/root", depth, MockTester)
  end

  test "adding a single path" do
    tests = [
      {"/path1/something.mp3", "/path1"},
      {"/path1/path2/something.mp3", "/path1/path2"},
      {"/path1/path2/path3/something.mp3", "/path1/path2"},
    ]
    Enum.each tests, fn({path, expected}) ->
      m = M.update(new(2), path)
      assert M.paths(m) == [expected]
    end
  end

  test "paths sharing a common directory" do
    paths = [
      "/path1/path2/path3/a.mp3",
      "/path1/path2/path3/b.mp3",
      "/path1/path2/path3/c.mp3",
      "/path1/path2/path3/d.mp3",
    ]
    m = Enum.reduce paths, new(2), fn(path, m) ->
      M.update(m, path)
    end
    assert M.paths(m) == ["/path1/path2"]
  end

  test "paths sharing a common root" do
    paths = [
      "/path1/path2/path3/a.mp3",
      "/path1/path2/path4/b.mp3",
      "/path1/path2/path5/c.mp3",
      "/path1/path2/path6/d.mp3",
    ]
    m = Enum.reduce paths, new(2), fn(path, m) ->
      M.update(m, path)
    end
    assert M.paths(m) == ["/path1/path2"]
  end

  test "paths without a common root" do
    paths = [
      "/path1/path2/path3/a.mp3",
      "/path1/path3/path3/b.mp3",
      "/path1/path4/path3/c.mp3",
      "/path1/path3/path3/d.mp3",
    ]
    m = Enum.reduce paths, new(2), fn(path, m) ->
      M.update(m, path)
    end
    assert M.paths(m) == [
      "/path1/path2",
      "/path1/path3",
      "/path1/path4",
    ]
  end

  test "relative paths without a common root" do
    paths = [
      "path1/path2/path3/a.mp3",
      "path1/path3/path3/b.mp3",
      "path1/path4/path3/c.mp3",
      "path1/path3/path3/d.mp3",
    ]
    m = Enum.reduce paths, new(2), fn(path, m) ->
      M.update(m, path)
    end
    assert M.paths(m) == [
      "path1/path2",
      "path1/path3",
      "path1/path4",
    ]
  end

  test "paths without a common root at higher depth" do
    paths = [
      "/path0/path1/path2/path3/a.mp3",
      "/path0/path1/path3/path3/b.mp3",
      "/path0/path1/path4/path3/c.mp3",
      "/path0/path1/path3/path3/d.mp3",
    ]
    m = Enum.reduce paths, new(3), fn(path, m) ->
      M.update(m, path)
    end
    assert M.paths(m) == [
      "/path0/path1/path2",
      "/path0/path1/path3",
      "/path0/path1/path4",
    ]
  end
end
