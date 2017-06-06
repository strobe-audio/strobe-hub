defmodule Plug.WebDav.Handler do

  import Plug.Conn
  import Plug.WebDav.Handler.Common

  alias Plug.WebDav.Handler.Propfind
  alias Plug.WebDav.Handler.Mkcol
  alias Plug.WebDav.Handler.Put
  alias Plug.WebDav.Handler.Get
  alias Plug.WebDav.Handler.Move
  alias Plug.WebDav.Handler.Delete

  require Logger

  def init(opts) do
    case Keyword.pop(opts, :root) do
      {nil, _opts} ->
        raise ArgumentError, "WebDav options must include a :root key"
      {root, opts} ->
        {Path.expand(root), opts}
    end
  end

  @allow ~w(
    OPTIONS
    PROPFIND
    MKCOL
    PUT
    GET
    MOVE
    DELETE

    HEAD
    COPY
  )
  # Unsupported?
  # POST
  # PROPPATCH
  # LOCK
  # UNLOCK
  # ORDERPATCH

  @allow_header Enum.join(@allow, ",")

  def call(conn, opts) do
    IO.inspect [__MODULE__, conn.method, conn.request_path, conn.path_info]
    conn |> dav_headers(opts) |> match(conn.method, file_path(conn, opts), opts)
  end

  defp file_path(conn, {root, _}) do
    path = [root | Enum.map(conn.path_info, &URI.decode/1)] |> Path.join |> Path.expand
    path_length = path |> Path.split |> length()
    root_length = root |> Path.split |> length()
    cond do
      path_length > root_length ->
        {:ok, path, path_length - root_length}
      # Need to allow PROPFIND on root itself
      path == root ->
        {:ok, path, 0}
      true ->
        :forbidden
    end
  end

  defp match(conn, _method, :forbidden, _opts) do
    send_resp(conn, 403, "Forbidden")
  end

  defp match(conn, "OPTIONS", _file_path, _opts) do
    conn
    |> put_resp_header("allow", @allow_header)
    |> send_resp(200, "")
  end

  defp match(conn, "PROPFIND", {:ok, file_path, _depth}, opts) do
    case Propfind.call(conn, file_path, directory(file_path), opts) do
      {:ok, props} ->
        send_resp(conn, 207, props)
      {:error, status, reason} ->
        Logger.warn "PROPFIND error #{inspect status} #{inspect reason}"
        send_resp(conn, status, reason)
    end
  end

  # Don't allow MKCOL at the same level as the root
  defp match(conn, "MKCOL", {:ok, _file_path, 0}, _opts) do
    Logger.warn "MKCOL error forbidden"
    send_resp(conn, 403, "Forbidden")
  end
  defp match(conn, "MKCOL", {:ok, file_path, _depth}, opts) do
    case Mkcol.call(conn, file_path, opts) do
      {:ok, resp, conn} ->
        send_resp(conn, 201, resp)
      {:error, status, reason, conn} ->
        Logger.warn "MKCOL error #{inspect status} #{inspect reason}"
        send_resp(conn, status, reason)
    end
  end

  defp match(conn, "PUT", {:ok, _file_path, 0}, _opts) do
    send_resp(conn, 403, "Forbidden")
  end
  defp match(conn, "PUT", {:ok, file_path, _depth}, opts) do
    case Put.call(conn, file_path, opts) do
      {:ok, resp, conn} ->
        send_resp(conn, 200, resp)
      {:error, status, reason, conn} ->
        send_resp(conn, status, reason)
    end
  end

  defp match(conn, "GET", {:ok, _file_path, 0}, _opts) do
    # TODO: some kind of html page that would allow directory browsing?
    send_resp(conn, 405, "Method not allowed")
  end
  defp match(conn, "GET", {:ok, file_path, _depth}, opts) do
    case Get.call(conn, file_path, opts) do
      # we use Conn.send_file which delegates to the adapter so there's nothing
      # to do here
      {:ok, conn} -> conn
      {:error, status, reason, conn} ->
        send_resp(conn, status, reason)
    end
  end

  defp match(conn, "MOVE", {:ok, _file_path, 0}, _opts) do
    # TODO: some kind of html page that would allow directory browsing?
    send_resp(conn, 400, "Invalid move")
  end
  defp match(conn, "MOVE", {:ok, file_path, _depth}, opts) do
    case Move.call(conn, file_path, opts) do
      {:ok, status, conn} ->
        send_resp(conn, status, "")
      {:error, status, reason, conn} ->
        send_resp(conn, status, reason)
    end
  end

  defp match(conn, "DELETE", {:ok, _file_path, 0}, _opts) do
    # TODO: some kind of html page that would allow directory browsing?
    send_resp(conn, 403, "Forbidden")
  end
  defp match(conn, "DELETE", {:ok, file_path, _depth}, opts) do
    case Delete.call(conn, file_path, opts) do
      {:ok, conn} ->
        send_resp(conn, 204, "")
      {:error, status, reason, conn} ->
        send_resp(conn, status, reason)
    end
  end

  defp match(conn, method, _path, _opts) do
    conn
    |> send_resp(405, "Method #{method} not allowed")
  end

end
