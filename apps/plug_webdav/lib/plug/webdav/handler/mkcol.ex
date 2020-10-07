defmodule Plug.WebDAV.Handler.Mkcol do
  import Plug.Conn
  import Plug.WebDAV.Handler.Common

  def call(conn, path, opts) do
    mkcol_safe(conn, path, exists?(path), opts)
  end

  defp exists?(path) do
    {File.exists?(path), File.dir?(path)}
  end

  defp mkcol_safe(conn, _path, {true, _}, _opts) do
    {:error, 409, "Conflict", conn}
  end

  defp mkcol_safe(conn, path, {false, _}, opts) do
    mkcol_read_body(read_body(conn), path, opts)
  end

  defp mkcol_read_body({:ok, "", conn}, path, opts) do
    mkcol(conn, path, opts)
  end

  defp mkcol_read_body({state, _body, conn}, _path, _opts) when state in [:ok, :more] do
    {:error, 415, "Unsupported Media Type", conn}
  end

  defp mkcol(conn, path, {root, _} = _opts) do
    case validate_tree(path, root) do
      {:ok, root, dir} ->
        case [root, dir] |> Path.join() |> File.mkdir_p() do
          :ok ->
            {:ok, "", conn}

          {:error, reason} ->
            {:error, 500, to_string(reason), conn}
        end

      {:error, _path} ->
        {:error, 409, "Conflict", conn}
    end
  end
end
