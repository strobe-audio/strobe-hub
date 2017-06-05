defmodule Peel.Webdav.ClassifierTest do
  use   ExUnit.Case, async: true
  use   Plug.Test

  alias Peel.Webdav.Classifier
  require Classifier

  setup do
    tmp = System.tmp_dir!
    root = [tmp, "ClassifierTest-#{System.unique_integer([:positive])}"] |> Path.join
    File.mkdir_p(root)
    on_exit fn ->
      File.rm_rf!(root)
    end
    {:ok, root: root}
  end

  test "sets connection assigns", context do
    [context.root, "something"] |> Path.join |> File.mkdir_p
    conn = conn("GET", "/something") |> Classifier.call({context.root, []})
    assert conn.assigns[:type] == :directory
  end

  test "URI decodes paths", context do
    [context.root, "something here"] |> Path.join |> File.mkdir_p
    conn = conn("GET", "/something%20here") |> Classifier.call({context.root, []})
    assert conn.assigns[:type] == :directory
  end

  test "path_type :directory", %{root: root} = _context do
    dir = [root, "something"] |> Path.join
    dir |> File.mkdir_p
    assert Classifier.path_type(conn("GET", "/something"), root) == {:directory, "/something"}
  end

  test "path_type :hidden", %{root: root} = _context do
    hidden = [root, ".hidden"] |> Path.join
    File.write!(hidden, "shhh", [:binary, :write])
    assert Classifier.path_type(conn("GET", "/.hidden"), root) == {:hidden, "/.hidden"}
  end

  test "path_type :hidden with non-existing file", %{root: root} = _context do
    assert Classifier.path_type(conn("GET", "/.hidden-again"), root) == {:hidden, "/.hidden-again"}
  end

  test "path_type :file", %{root: root} = _context do
    regular = [root, "regular.mp3"] |> Path.join
    File.write!(regular, "hello", [:binary, :write])
    assert Classifier.path_type(conn("GET", "/regular.mp3"), root) == {:file, "/regular.mp3"}
  end

  test "path_type :new", %{root: root} = _context do
    assert Classifier.path_type(conn("GET", "/who.mp3"), root) == {:new, "/who.mp3"}
  end

  test "path_type :special", %{root: root} = _context do
    special = [root, "pipe"] |> Path.join
    System.cmd "mkfifo", [special]
    assert Classifier.path_type(conn("GET", "/pipe"), root) == {:special, "/pipe"}
  end

  test "path_type :root", cxt do
    assert Classifier.path_type(conn("GET", "/"), cxt.root) == {:root, "/"}
  end
end
