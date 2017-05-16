defmodule Peel.Webdav.HandlerTest do
  use   ExUnit.Case, async: true

  alias Peel.Webdav.Handler
  require Handler

  setup do
    tmp = System.tmp_dir!
    root = [tmp, "HandlerTest-#{System.unique_integer([:positive])}"] |> Path.join
    File.mkdir_p(root)
    on_exit fn ->
      File.rm_rf!(root)
    end
    {:ok, root: root}
  end

  def arg(root, path) do
    Handler.arg(docroot: to_charlist(root), pathinfo: to_charlist(path))
  end

  test "path_type :directory", %{root: root} = _context do
    dir = [root, "something"] |> Path.join
    dir |> File.mkdir_p
    assert Handler.path_type(arg(root, "something")) == {:directory, dir}
  end

  test "path_type :hidden", %{root: root} = _context do
    hidden = [root, ".hidden"] |> Path.join
    File.write!(hidden, "shhh", [:binary, :write])
    assert Handler.path_type(arg(root, "/.hidden")) == {:hidden, hidden}
  end

  test "path_type :hidden with non-existing file", %{root: root} = _context do
    hidden = [root, ".hidden-again"] |> Path.join
    assert Handler.path_type(arg(root, "/.hidden-again")) == {:hidden, hidden}
  end

  test "path_type :file", %{root: root} = _context do
    regular = [root, "regular.mp3"] |> Path.join
    File.write!(regular, "hello", [:binary, :write])
    assert Handler.path_type(arg(root, "/regular.mp3")) == {:file, regular}
  end

  test "path_type :new", %{root: root} = _context do
    assert Handler.path_type(arg(root, "/who.mp3")) == {:new, Path.join(root, "who.mp3")}
  end

  test "path_type :special", %{root: root} = _context do
    special = [root, "pipe"] |> Path.join
    System.cmd "mkfifo", [special]
    assert Handler.path_type(arg(root, "/pipe")) == {:special, special}
  end

  test "path_type :none" do
    assert Handler.path_type(Handler.arg(pathinfo: :undefined)) == :none
  end
end
