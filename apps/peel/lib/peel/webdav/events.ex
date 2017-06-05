defmodule Peel.Webdav.Events do
  alias  Plug.Conn

  def init(opts) do
    IO.inspect [__MODULE__, :init, opts]
    case Keyword.pop(opts, :root) do
      {nil, _opts} ->
        raise ArgumentError, "WebDav options must include a :root key"
      {root, opts} ->
        {Path.expand(root), opts}
    end
  end

  def call(conn, opts) do
    IO.inspect [__MODULE__, conn.method, conn.status, conn.req_headers, conn.resp_headers]
    conn |> handle_request(conn.method, conn.status, opts)
  end

  defp handle_request(%Conn{path_info: [collection_name]} = conn, "MKCOL", 201, _opts) do
    emit_event({:create, [:collection, collection_name]})
    conn
  end

  defp handle_request(%Conn{path_info: path_info} = conn, "PUT", ok, _opts)
  when ok in [200, 201, 204] do
    emit_event({:create, [:file, path(path_info)]})
    conn
  end

  defp handle_request(%Conn{path_info: path_info} = conn, "MOVE", ok, _opts)
  when ok in [201, 204] do
    emit_event({:move, [conn.assigns[:type], path(path_info), conn.assigns[:destination]]})
    conn
  end

  defp handle_request(conn, _method, _status, _opts) do
    conn
  end

  defp emit_event(event) do
    event |> Peel.Webdav.Modifications.notify
  end

  defp path(path_info), do: ["/" | path_info] |> Path.join
end
