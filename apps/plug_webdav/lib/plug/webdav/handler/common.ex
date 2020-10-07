defmodule Plug.WebDAV.Handler.Common do
  alias Plug.Conn, as: C

  @dav_levels ~w(1 2)
  @dav_header Enum.join(@dav_levels, ",")

  def dav_headers(conn, _opts) do
    conn
    |> C.put_resp_header("dav", @dav_header)
    |> C.put_resp_header("content-type", "text/xml; charset=utf-8")
  end

  def directory(path) do
    cond do
      !File.exists?(path) ->
        {:error, :enoent}

      File.dir?(path) ->
        {:ok, path}

      true ->
        {:ok, Path.dirname(path)}
    end
  end

  def path_relative_to(root, root), do: ""

  def path_relative_to(path, root) do
    Path.relative_to(path, root)
  end

  def path_join(path), do: path_join(path, false)
  def path_join([], true), do: "/"
  def path_join([], false), do: ""
  def path_join(path, true), do: Path.join(["/" | path])
  def path_join(path, false), do: Path.join(path)

  def validate_tree(path, root) when is_binary(path) do
    rel_path = path |> Path.relative_to(root)
    [child | ancestors] = rel_path |> Path.split() |> Enum.reverse()
    ancestors |> Enum.reverse() |> validate_tree(root, child)
  end

  defp validate_tree([], root, child) do
    {:ok, root, child}
  end

  defp validate_tree([parent | parts], root, child) do
    path = [root, parent] |> Path.join() |> Path.expand()

    case directory?(path) do
      {true, true} ->
        validate_tree(parts, path, child)

      _noent ->
        {:error, path}
    end
  end

  defp directory?(path) do
    {File.exists?(path), File.dir?(path)}
  end
end
