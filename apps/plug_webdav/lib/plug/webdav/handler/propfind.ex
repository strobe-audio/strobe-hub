defmodule Plug.WebDAV.Handler.Propfind do
  import Plug.WebDAV.Handler.Common
  import Plug.Conn

  require Record

  def call(conn, path, dir, opts) do
    {propspecs, conn} =
      case read_body(conn) do
        {:ok, "", conn} ->
          {allprop(), conn}
        {:ok, body, conn} ->
          {body |> parse_propfind_body, conn}
      end
    conn |> get_req_header("depth") |> propfind_depth(path, dir, propspecs, conn, opts)
  end

  defp parse_propfind_body(body) do
    import SweetXml
    doc =
      body
      |> parse(namespace_conformant: true)

    doc
    |> xpath(~x"/d:propfind//d:prop/node()"l |> add_namespace("d", "DAV:"))
    |> Enum.filter(&Record.is_record(&1, :xmlElement))
    |> Enum.map(fn(xmlElement(expanded_name: {uri, local}, nsinfo: nsinfo)) ->
      {to_atom(local), {uri, nsinfo}}
    end)
    |> match_allprops(doc)
  end

  defp to_atom(tag) when is_atom(tag), do: tag
  defp to_atom(tag) when is_list(tag), do: List.to_existing_atom(tag)


  defp match_allprops([], doc) do
    import SweetXml
    case xpath(doc, ~x"/d:propfind//d:allprop" |> add_namespace("d", "DAV:")) do
      nil -> []
      _el -> allprop()
    end
  end

  defp match_allprops(props, _doc) do
    props
  end

  defp propfind_depth(_depth, _path, {:error, :enoent}, _propfind, _conn, _opts) do
    {:error, 404, ""}
  end
  defp propfind_depth(["1"], dir, {:ok, dir}, propfind, conn, opts) do
    {:ok, files} = File.ls(dir)
    propfind_response(["." | files], dir, propfind, conn, opts)
  end
  defp propfind_depth(["0"], dir, {:ok, dir}, propfind, conn, opts) do
    propfind_response(["."], dir, propfind, conn, opts)
  end
  defp propfind_depth(["0"], file, {:ok, dir}, propfind, conn, opts) do
    propfind_response([Path.basename(file)], dir, propfind, conn, opts)
  end
  defp propfind_depth(_depth, _path, _dir, _propfind, _conn, _opts) do
    {:error, 403, [
      ~s(<?xml version="1.0" encoding="UTF-8"?>),
      ~s(<d:error xmlns:d="DAV:">),
      ~s(<d:propfind-finite-depth/>),
      ~s(</d:error>),
    ]}
  end

  defp propfind_response(files, dir, propfind, conn, opts) do
    responses =
      files
      |> Stream.map(&({&1, [dir, &1] |> Path.join}))
      |> Stream.map(fn {name, path} -> {name, path, File.stat!(path)} end)
      |> Enum.map(&propfind_resource(&1, propfind, conn, opts))
    resp = [
      ~s(<?xml version="1.0" encoding="UTF-8"?>),
      ~s(<d:multistatus xmlns:d="DAV:">),
      responses,
      ~s(</d:multistatus>),
    ]
    {:ok, resp}
  end

  defp propfind_resource({_name, path, _stat} = file, propfind, conn, opts) do
    props =
      propfind
      |> Enum.map(&propfind(file, &1, opts))
      |> Enum.group_by(fn {status, _values} -> status end, fn {_status, values} -> values end)
      |> Enum.map(&propstat/1)
    [ "<d:response>",
      "<d:href><![CDATA[", resource_href(path, conn, opts), "]]></d:href>",
      props,
      "</d:response>",
    ]
  end

  defp resource_href(path, conn, {root, _}) do
    path
    |> Path.expand() # remove any trailing '.'
    |> path_relative_to(root)
    |> Path.split()
    |> scope_path(conn)
    |> Enum.map(&URI.encode/1)
    |> path_join(true)
  end

  defp scope_path(path, %Plug.Conn{script_name: script_name}) when is_list(path) do
    Enum.concat(script_name, path)
  end

  defp propstat({status, values}) do
    [ "<d:propstat>",
      "<d:prop>", values, "</d:prop>",
      "<d:status>HTTP/1.1 ", propstatus(status), "</d:status>",
      "</d:propstat>",
    ]
  end

  defp propstatus(200), do: "200 OK"
  defp propstatus(401), do: "401 Unauthorized"
  defp propstatus(403), do: "403 Forbidden"
  defp propstatus(404), do: "404 Not Found"

  defp propfind({_name, _path, stat}, {:getcontentlength, _dav}, _opts) do
    {200, ["<d:getcontentlength>", stat.size |> to_string, "</d:getcontentlength>"]}
  end
  defp propfind({_name, _path, stat}, {:resourcetype, _dav}, _opts) do
    resp =
      case stat.type do
        :directory ->
          ["<d:resourcetype>", "<d:collection/>", "</d:resourcetype>"]
        _ ->
          "<d:resourcetype/>"
      end
    {200, resp}
  end
  defp propfind({name, _path, stat}, {:getcontenttype, _dav}, _opts) do
    type =
      case stat.type do
        :directory -> "httpd/unix-directory"
        :regular -> MIME.from_path(name)
      end
    {200, ["<d:getcontenttype>", type, "</d:getcontenttype>"]}
  end
  defp propfind({_name, path, _stat}, {:displayname, _dav}, {root, _}) do
    displayname =
      cond do
        Path.expand(path) == root -> ""
        true ->
          path |> Path.expand |> Path.basename
      end
    {200, ["<d:displayname><![CDATA[", displayname, "]]></d:displayname>"]}
  end
  defp propfind({_name, _path, stat}, {:getlastmodified, _dav}, _opts) do
    {200, ["<d:getlastmodified>", stat.mtime |> Plug.WebDAV.Time.format, "</d:getlastmodified>"]}
  end
  defp propfind({_name, _path, stat}, {:creationdate, _dav}, _opts) do
    {200, ["<d:creationdate>", stat.ctime |> Plug.WebDAV.Time.format, "</d:creationdate>"]}
  end
  defp propfind(_, {_prop, {url, {prefix, prop}}}, _opts) do
    {404, ["<", to_string(prefix), ":", to_string(prop), " xmlns:", prefix, "=\"", to_string(url), "\"", "/>"]}
  end
  defp propfind(_, {prop, {url, []}}, _opts) do
    {404, ["<", to_string(prop), " xmlns=\"", to_string(url), "\"", "/>"]}
  end

  @allprop [
    :creationdate,
    :displayname,
    :getcontentlength,
    :getcontenttype,
    :getlastmodified,
    :resourcetype,
  ] |> Enum.map(fn p -> {p, {'d', :"DAV:"}} end)

  def allprop, do: @allprop
end
