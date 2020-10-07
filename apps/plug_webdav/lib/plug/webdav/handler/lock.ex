defmodule Plug.WebDAV.Handler.Lock do
  import Plug.Conn

  alias Plug.WebDAV.Lock

  def lock(conn, _path, opts) do
    case read_body(conn) do
      {:ok, "", conn} ->
        {:error, 412, conn}

      {:ok, body, conn} ->
        body |> parse_request(conn) |> lock_resource(conn, opts)
    end
  end

  def unlock(%Plug.Conn{path_info: path} = conn, _path, {root, _opts}) do
    # {"lock-token", lock_id} = List.keyfind(headers, "lock-token", 0)
    tokens = conn |> get_req_header("lock-token") |> parse_locktokens()

    case Lock.release(root, path, tokens) do
      :ok ->
        {:ok, conn}

      {:error, reason} ->
        {:error, 409, to_string(reason), conn}
    end
  end

  defp parse_request(body, conn) do
    import SweetXml
    doc = body |> parse(namespace_conformant: true)

    params =
      doc
      |> xpath(~x"/d:lockinfo" |> add_namespace("d", "DAV:"),
        lockscope: ~x"./d:lockscope/node()" |> add_namespace("d", "DAV:"),
        locktype: ~x"./d:locktype/node()" |> add_namespace("d", "DAV:")
      )

    {:"DAV:", scope} = xmlElement(params.lockscope, :expanded_name)
    {:"DAV:", type} = xmlElement(params.locktype, :expanded_name)

    case {scope, type} do
      {:exclusive, :write} ->
        opts =
          [depth: lock_depth(conn), timeout: lock_timeout(conn)]
          |> clean_opts()

        {:ok, opts}

      _ ->
        {:error, "Unsupported lock type #{scope} / #{type}"}
    end
  end

  defp lock_resource({:error, reason}, conn, _opts) do
    {:error, 412, reason, conn}
  end

  defp lock_resource({:ok, params}, %Plug.Conn{path_info: path} = conn, {root, _opts}) do
    case Lock.acquire_exclusive(root, path, params) do
      {:ok, lock} ->
        body = [
          ~s(<?xml version="1.0" encoding="utf-8"?>),
          ~s(<d:prop xmlns:d="DAV:">),
          Lock.lockdiscovery_property([lock]),
          ~s(</d:prop>)
        ]

        conn = conn |> put_resp_header("lock-token", "<#{lock.id}>")
        {:ok, body, conn}

      {:error, :duplicate, _locks} ->
        {:error, 409, "", conn}
    end
  end

  defp lock_depth(conn) do
    case get_req_header(conn, "depth") do
      ["0"] -> 0
      _ -> :infinity
    end
  end

  defp lock_timeout(conn) do
    case get_req_header(conn, "timeout") do
      [timeout] ->
        parse_lock_timeout(timeout)

      _ ->
        nil
    end
  end

  defp parse_lock_timeout(header) do
    header
    |> String.downcase()
    |> String.split(~r{ *, *}, trim: true)
    |> Enum.map(&String.split(&1, "-"))
    |> Enum.filter(fn
      ["second", _seconds] -> true
      _ -> false
    end)
    |> Enum.map(fn
      ["second", seconds] -> String.to_integer(seconds)
    end)
    |> List.first()
  end

  defp clean_opts(opts) do
    Enum.reject(opts, fn {_, v} -> is_nil(v) end)
  end

  defp parse_locktokens([]), do: []

  defp parse_locktokens(tokens) do
    parse_locktokens(tokens, [])
  end

  defp parse_locktokens([token | rest], parsed) do
    parse_locktokens(rest, [unwrap_locktoken(token) | parsed])
  end

  defp parse_locktokens([], parsed) do
    parsed
  end

  defp unwrap_locktoken(<<"<", t::binary>>) do
    unwrap_locktoken(t, [])
  end

  defp unwrap_locktoken(t) do
    t
  end

  defp unwrap_locktoken(<<">", _::binary>>, parsed) do
    parsed |> Enum.reverse() |> IO.iodata_to_binary()
  end

  defp unwrap_locktoken(<<c::binary-1, r::binary>>, parsed) do
    unwrap_locktoken(r, [c | parsed])
  end
end
