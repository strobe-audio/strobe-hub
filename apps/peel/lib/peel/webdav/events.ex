defmodule Peel.Webdav.Events do
  def init(opts) do
    case Keyword.pop(opts, :root) do
      {nil, _opts} ->
        raise ArgumentError, "WebDav options must include a :root key"
      {root, opts} ->
        {Path.expand(root), opts}
    end
  end

  def call(conn, opts) do
    handle_request(conn, Enum.map(conn.path_info, &URI.decode/1), conn.method, conn.status, opts)
    conn
  end

  defp handle_request(_conn, [collection_name], "MKCOL", 201, _opts) do
    emit_event({:create, [:collection, collection_name]})
  end

  defp handle_request(_conn, path_info, "PUT", ok, _opts)
  when ok in [200, 201, 204] do
    emit_event({:create, [:file, path(path_info)]})
  end

  defp handle_request(conn, path_info, "MOVE", ok, _opts)
  when ok in [201, 204] do
    emit_event({:move, [conn.assigns[:type], path(path_info), conn.assigns[:destination]]})
  end

  defp handle_request(conn, path_info, "DELETE", 204, _opts) do
    emit_event({:delete, [conn.assigns[:type], path(path_info)]})
  end

  defp handle_request(_conn, _path_info, _method, _status, _opts) do
  end

  defp emit_event(event) do
    event |> Peel.Webdav.Modifications.notify
  end

  defp path(path_info), do: ["/" | path_info] |> Path.join
end
