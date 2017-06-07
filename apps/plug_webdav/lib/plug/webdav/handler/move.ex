defmodule Plug.WebDAV.Handler.Move do
  import Plug.Conn
  import Plug.WebDAV.Handler.Common

  def call(conn, path, opts) do
    move(conn, path, exists?(path), destination(conn), opts)
  end

  defp move(conn, _src, false, _dst, _opts) do
    {:error, 404, "Not Found", conn}
  end
  defp move(conn, _src, true, {:error, reason}, _opts) do
    {:error, 409, reason, conn}
  end
  defp move(conn, src, true, {:ok, rel_dst}, {root, _} = opts) do
    # TODO: protect against root traversal in dest
    dst = [root, rel_dst] |> Path.join |> Path.expand
    conn
    |> assign(:destination, rel_dst)
    |> do_move(src, dst, opts)
  end

  defp do_move(conn, src, src, _opts) do
    {:error, 403, "Forbidden", conn}
  end
  defp do_move(conn, src, dst, {root, _} = _opts) do
    case validate_tree(dst, root) do
      {:ok, _root, _child} ->
        status =
          if File.exists?(dst) do
            204
          else
            201
          end
        case File.rename(src, dst) do
          :ok ->
            {:ok, status, conn}
          {:error, err} ->
            {:error, 500, to_string(err), conn}
        end
      {:error, _root} ->
        {:error, 409, "Conflict", conn}
    end
  end

  defp exists?(path) do
    File.exists?(path)
  end

  defp destination(conn) do
    case get_req_header(conn, "destination") do
      [destination | _] ->
        parse_destination(conn, destination)
      [] ->
        {:error, 400, "Missing destination header", conn}
    end
  end

  defp parse_destination(conn, destination) do
    uri = URI.parse(destination)
    # If the plug is mounted under some scope in phoenix, then the scope path
    # comes through in `script_name` and the `path_info` is relative to that
    # scope so we need to take our destination path relative to the scope path
    # too
    src = source_host(conn)
    dst = URI.merge(src, uri)

    if src.host == dst.host && src.port == dst.port do
      scope = ["/" | conn.script_name] |> Path.join
      path = URI.decode(dst.path) |> Path.relative_to(scope)
      {:ok, "/#{path}"}
    else
      {:error, "Invalid destination"}
    end
  end

  defp source_host(conn) do
    %URI{ authority: "#{conn.host}:#{conn.port}",
      scheme: conn.scheme,
      host: conn.host,
      path: ["/"|conn.path_info] |> Path.join,
      port: conn.port
    }
  end
end
