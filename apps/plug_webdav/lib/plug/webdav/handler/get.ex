defmodule Plug.WebDav.Handler.Get do
  import Plug.Conn

  def call(conn, path, opts) do
    get(exist?(path), conn, path, opts)
  end

  defp get({true, true}, conn, path, _opts) do
    conn = put_resp_header(conn, "content-type", MIME.from_path(path))
    {:ok, send_file(conn, 200, path)}
  end

  defp get({true, false}, conn, _path, _opts) do
    {:error, 405, "Method Not Allowed", conn}
  end

  defp get(_missing, conn, _path, _opts) do
    {:error, 404, "Not Found", conn}
  end

  defp exist?(path) do
    {File.exists?(path), File.regular?(path)}
  end
end
