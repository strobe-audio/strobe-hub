defmodule Peel.Webdav.LibraryModification do
  @moduledoc """
  Coalesces modified paths in the filesystem into a set of roots of a certain
  path length which contain the modifications.
  """

  defmodule FilesystemTester do
    @moduledoc false
    def is_file?(path) do
      File.regular?(path)
    end
    def is_dir?(path) do
      File.dir?(path)
    end
  end

  defstruct [
    root: "/",
    depth: 1,
    paths: [],
    tester: FilesystemTester,
  ]

  alias __MODULE__, as: M

  def new(root, depth, type_tester \\ FilesystemTester) do
    %M{root: root, depth: depth, tester: type_tester}
  end

  def update(%M{} = m, path) when is_binary(path) do
    with {:ok, dir} = dirname(m, path),
      root <- root(m, dir),
      do: _update(m, root)
  end

  def paths(%M{paths: paths}) do
    Enum.sort(paths)
  end

  defp _update(%M{paths: []} = m, root) do
    %M{m | paths: [root]}
  end
  defp _update(%M{paths: paths} = m, root) do
    if Enum.any?(paths, fn(p) -> p == root end) do
      m
    else
      %M{m | paths: [root | paths]}
    end
  end


  defp dirname(%M{tester: tester} = m, path) do
    abs = abs_path(m, path)
    cond do
      tester.is_file?(abs)  -> {:ok, Path.dirname(path)}
      tester.is_dir?(abs) -> {:ok, path}
      # we're often testing for paths that don't exist yet
      true -> {:ok, Path.dirname(path)}
    end
  end

  defp abs_path(%M{root: root}, path), do: [root, path] |> Path.join

  defp root(%M{depth: depth}, <<"/", _rest::binary>> = path) do
    _root(depth + 1, path)
  end
  defp root(%M{depth: depth}, path) do
    _root(depth, path)
  end
  defp _root(depth, path) when is_integer(depth) do
    path |> Path.split |> Enum.take(depth) |> Path.join
  end
end
