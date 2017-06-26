defmodule Plug.WebDAVTest do
  use ExUnit.Case
  use Plug.Test

  alias Plug.WebDAV.Handler.Propfind
  alias Plug.WebDAV.Lock

  @handler Plug.WebDAV.Handler

  setup do
    root =
      [System.tmp_dir!, "Plug.WebDAV", DateTime.utc_now |> DateTime.to_unix |> to_string]
      |> Path.join

    File.mkdir_p(root)
    Lock.reset!

    on_exit fn ->
      File.rm_rf(root)
    end

    {:ok, root: root, opts: {root, []}}
  end

  def request(conn, opts \\ [])
  def request(conn, %{opts: opts}) do
    request(conn, opts)
  end
  def request(conn, opts) do
    @handler.call(conn, opts)
  end

  def assert_header(conn, header, value) do
    {_status, headers, _body} = sent_resp(conn)
    assert {header, value} == List.keyfind(headers, header, 0)
  end

  test "init function moves root into first place", cxt do
    assert {cxt.root, []} == @handler.init([root: cxt.root])
  end

  describe "OPTIONS" do
    test "Returns appropriate allowed methods", cxt do
      conn = conn(:options, "/") |> request(cxt)
      {204, _headers, ""} = sent_resp(conn)
      assert_header(conn, "allow", "OPTIONS,PROPFIND,MKCOL,PUT,GET,MOVE,DELETE,POST,HEAD,COPY,LOCK,UNLOCK")
    end

    test "returns correct dav: header", cxt do
      conn = conn(:options, "/") |> request(cxt)
      assert_header(conn, "dav", "1,2")
      # {200, headers, ""} = sent_resp(conn)
      # assert {"dav", "1"} == List.keyfind(headers, "dav", 0)
    end
  end

  def parse_response(body) do
    body
    |> SweetXml.parse(namespace_conformant: true)
  end

  def parse_proplist(body) do
    body
    |> parse_response
    |> SweetXml.xmap(responses: [
      xpath("/d:multistatus//d:response", 'l'),
      href: xpath("./d:href/text()", 's'),
      propstat: [
        xpath(".//d:propstat", 'l'),
        status: xpath("./d:status/text()", 's'),
        props: [
          xpath("./d:prop/*", 'l'),
          name: xpath("name()", 's'),
          value: xpath("./text()", 'S'),
        ]
      ]
    ])
  end

  def xpath(selector, modifiers \\ '') do
    SweetXml.sigil_x(selector, modifiers) |> SweetXml.add_namespace("d", "DAV:")
  end

  describe "PROPFIND" do
    test "returns a content type of text/xml; encoding=utf-8", cxt do
      conn = conn(:propfind, "/") |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, _body} = sent_resp(conn)
      assert_header(conn, "content-type", "text/xml; charset=utf-8")
    end

    test "PROPFIND /directory", cxt do
      path = "/sub-directory"
      [cxt.root, path] |> Path.join |> File.mkdir_p
      conn = conn(:propfind, path, "") |> put_req_header("depth", "1") |> request(cxt)
      {301, headers, _body} = sent_resp(conn)
      {"location", location} = List.keyfind(headers, "location", 0)
      assert location == path <> "/"
    end

    test "it returns the requested properties of any existing files", cxt do
      File.write!([cxt.root, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop>
            <getcontentlength/>
            <resourcetype/>
          </prop>
        </propfind>
      )
      conn = conn(:propfind, "/", req) |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)
      # Response should include status of root directory as well as contents
      proplist =
        body
        |> parse_proplist
      assert length(proplist.responses) == 2
      [dir, file] = proplist.responses
      assert dir.href == "/"
      [propstat] = dir.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      [contentlength, resourcetype] = propstat.props
      assert contentlength.name == "{DAV:}getcontentlength"
      assert contentlength.value == "102"
      assert resourcetype.name == "{DAV:}resourcetype"
      assert resourcetype.value == ""
      # Test that the current dir has a resourcetype of '<d:collection/>'
      doc = body |> parse_response
      [:xmlElement, :"d:collection" | _] = SweetXml.xpath(doc, xpath("//d:response/d:href[text() = '/']/../d:propstat/d:prop/d:resourcetype/d:collection")) |> Tuple.to_list

      assert file.href == "/file.txt"
      [propstat] = file.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      [contentlength, resourcetype] = propstat.props
      assert contentlength.name == "{DAV:}getcontentlength"
      assert contentlength.value == "9"
      assert resourcetype.name == "{DAV:}resourcetype"
      assert resourcetype.value == ""
    end

    test "it returns all requested properties of any existing files", cxt do
      File.write!([cxt.root, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop>
            <getcontentlength/>
            <resourcetype/>
            <getcontenttype/> <displayname/>
            <getlastmodified/>
            <creationdate/>
          </prop>
        </propfind>
      )
      conn = conn(:propfind, "/", req) |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)
      # Response should include status of root directory as well as contents
      proplist =
        body
        |> parse_proplist
      assert length(proplist.responses) == 2
      [dir, file] = proplist.responses

      %File.Stat{mtime: mtime, ctime: ctime, size: size} = File.stat!(cxt.root)
      assert dir.href == "/"
      [propstat] = dir.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      [contentlength, resourcetype, contenttype, displayname, lastmodified, creationdate] = propstat.props
      assert contentlength.name == "{DAV:}getcontentlength"
      assert contentlength.value == to_string(size)
      assert resourcetype.name == "{DAV:}resourcetype"
      assert resourcetype.value == ""
      assert contenttype.name == "{DAV:}getcontenttype"
      assert contenttype.value == "httpd/unix-directory"
      assert displayname.name == "{DAV:}displayname"
      assert displayname.value == ""
      assert lastmodified.name == "{DAV:}getlastmodified"
      assert lastmodified.value == mtime |> NaiveDateTime.from_erl! |> Timex.to_datetime("UTC") |> Timex.format!("{RFC1123}")
      assert creationdate.name == "{DAV:}creationdate"
      assert creationdate.value == ctime |> NaiveDateTime.from_erl! |> Timex.to_datetime("UTC") |> Timex.format!("{RFC1123}")


      %File.Stat{mtime: mtime, ctime: ctime, size: size} = File.stat!([cxt.root, "file.txt"] |> Path.join)

      assert file.href == "/file.txt"
      [propstat] = file.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      [contentlength, resourcetype, contenttype, displayname, lastmodified, creationdate] = propstat.props
      assert contentlength.name == "{DAV:}getcontentlength"
      assert contentlength.value == to_string(size)
      assert resourcetype.name == "{DAV:}resourcetype"
      assert resourcetype.value == ""
      assert contenttype.name == "{DAV:}getcontenttype"
      assert contenttype.value == "text/plain"
      assert displayname.name == "{DAV:}displayname"
      assert displayname.value == "file.txt"
      assert lastmodified.name == "{DAV:}getlastmodified"
      assert lastmodified.value == mtime |> NaiveDateTime.from_erl! |> Timex.to_datetime("UTC") |> Timex.format!("{RFC1123}")
      assert creationdate.name == "{DAV:}creationdate"
      assert creationdate.value == ctime |> NaiveDateTime.from_erl! |> Timex.to_datetime("UTC") |> Timex.format!("{RFC1123}")
    end

    test "it returns a status of 404 for unknown properties", cxt do
      File.write!([cxt.root, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop>
            <getcontentlength/>
            <flibble:fliny xmlns:flibble="http://strobe.audio/flibble"/>
            <boom xmlns="http://strobe.audio/boom"/>
          </prop>
        </propfind>
      )
      conn = conn(:propfind, "/", req) |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)

      proplist =
        body
        |> parse_proplist

      assert length(proplist.responses) == 2
      [dir, _file] = proplist.responses

      [valid, invalid] = dir.propstat
      assert valid.status == "HTTP/1.1 200 OK"
      assert invalid.status == "HTTP/1.1 404 Not Found"
      [fliny, boom] = invalid.props
      assert fliny.name == "{http://strobe.audio/flibble}fliny"
      assert boom.name == "boom"
    end

    test "empty request returns all props", cxt do
      File.write!([cxt.root, "file.txt"] |> Path.join, "something", [:binary])
      conn = conn(:propfind, "/") |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)
      proplist =
        body
        |> parse_proplist
      assert length(proplist.responses) == 2
      [dir, _file] = proplist.responses
      assert dir.href == "/"
      [propstat] = dir.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      props = Enum.map(propstat.props, fn %{name: name} -> name end) |> Enum.sort
      allprop = Propfind.allprop |> Enum.map(fn {p, _} -> "{DAV:}#{p}" end) |> Enum.sort
      assert props == allprop
    end

    test "allprop request returns all props", cxt do
      File.write!([cxt.root, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <allprop/>
        </propfind>
      )
      conn = conn(:propfind, "/", req) |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)
      proplist =
        body
        |> parse_proplist
      assert length(proplist.responses) == 2
      [dir, _file] = proplist.responses
      assert dir.href == "/"
      [propstat] = dir.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      props = Enum.map(propstat.props, fn %{name: name} -> name end) |> Enum.sort
      allprop = Propfind.allprop |> Enum.map(fn {p, _} -> "{DAV:}#{p}" end) |> Enum.sort
      assert props == allprop
    end

    test "missing depth header returns error", cxt do
      File.write!([cxt.root, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <allprop/>
        </propfind>
      )
      conn = conn(:propfind, "/", req) |> request(cxt)
      {403, _headers, body} = sent_resp(conn)
      assert body == "<?xml version=\"1.0\" encoding=\"UTF-8\"?><d:error xmlns:d=\"DAV:\"><d:propfind-finite-depth/></d:error>"
    end

    test "depth of 0 returns only properties for dir", cxt do
      File.write!([cxt.root, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <allprop/>
        </propfind>
      )
      conn = conn(:propfind, "/", req) |> put_req_header("depth", "0") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)
      proplist =
        body
        |> parse_proplist
      assert length(proplist.responses) == 1
      [dir] = proplist.responses
      assert dir.href == "/"
    end

    test "propfind on individual file", cxt do
      File.write!([cxt.root, "file.txt"] |> Path.join, "something", [:binary])
      conn = conn(:propfind, "/file.txt") |> put_req_header("depth", "0") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)
      proplist =
        body
        |> parse_proplist
      assert length(proplist.responses) == 1
      [file] = proplist.responses
      assert file.href == "/file.txt"
    end

    test "subdirectories return correct urls", cxt do
      sub = ["Some Doors", "Are Green"]
      abs_sub = [cxt.root | sub] |> Path.join
      File.mkdir_p(abs_sub)
      File.write!([abs_sub, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop><getcontentlength/></prop>
        </propfind>
      )
      path = ["/" | Enum.map(sub, &URI.encode/1)] |> Path.join
      conn = conn(:propfind, path <> "/", req) |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)

      proplist =
        body
        |> parse_proplist

      assert length(proplist.responses) == 2
      [dir, file] = proplist.responses

      [propstat] = dir.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      assert dir.href == path <> "/"
      assert file.href == "#{path}/file.txt"
    end

    test "subdirectories return correct display names", cxt do
      sub = ["Some Doors", "Are Green"]
      abs_sub = [cxt.root | sub] |> Path.join
      File.mkdir_p(abs_sub)
      File.write!([abs_sub, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop><displayname/></prop>
        </propfind>
      )
      path = ["/" | Enum.map(sub, &URI.encode/1)] |> Path.join
      conn = conn(:propfind, path <> "/", req) |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)

      proplist =
        body
        |> parse_proplist

      assert length(proplist.responses) == 2
      [dir, file] = proplist.responses

      [propstat] = dir.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      assert dir.href == path <> "/"
      [propstat] = dir.propstat
      [displayname] = propstat.props
      assert displayname.value == "Are Green"
      assert file.href == "#{path}/file.txt"
    end

    test "handles names with ampersands", cxt do
      sub = ["Frank & Walters", "Blue & Green"]
      abs_sub = [cxt.root | sub] |> Path.join
      File.mkdir_p(abs_sub)
      File.write!([abs_sub, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop><displayname/></prop>
        </propfind>
      )
      path = ["/" | Enum.map(sub, &URI.encode/1)] |> Path.join
      conn = conn(:propfind, path <> "/", req) |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)

      proplist =
        body
        |> parse_proplist

      assert length(proplist.responses) == 2
      [dir, _file] = proplist.responses

      [propstat] = dir.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      assert dir.href == path <> "/"
      [propstat] = dir.propstat
      [displayname] = propstat.props
      assert displayname.value == "Blue & Green"
    end

    test "handles requests with namespaces", cxt do
      sub = ["Frank & Walters", "Blue & Green"]
      abs_sub = [cxt.root | sub] |> Path.join
      File.mkdir_p(abs_sub)
      File.write!([abs_sub, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <a:propfind xmlns:a="DAV:">
          <a:prop><a:displayname/></a:prop>
        </a:propfind>
      )
      path = ["/" | Enum.map(sub, &URI.encode/1)] |> Path.join
      conn = conn(:propfind, path <> "/", req) |> put_req_header("depth", "1") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)

      proplist =
        body
        |> parse_proplist

      assert length(proplist.responses) == 2
      [dir, _file] = proplist.responses

      [propstat] = dir.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      assert dir.href == path <> "/"
      [propstat] = dir.propstat
      [displayname] = propstat.props
      assert displayname.value == "Blue & Green"
    end

    test "returns 404 if directory is invalid", cxt do
      sub = ["Frank & Walters", "Are Great"]
      path = ["/" | Enum.map(sub, &URI.encode/1)] |> Path.join
      conn = conn(:propfind, path) |> put_req_header("depth", "1") |> request(cxt)
      {404, _headers, _body} = sent_resp(conn)
    end

    test "prevents reading of parent directories", cxt do
      conn = conn(:propfind, "/..") |> put_req_header("depth", "1") |> request(cxt)
      {403, _headers, "Forbidden"} = sent_resp(conn)
    end

    test "prevents reading of sibling directories", cxt do
      [cxt.root, "../immoral"] |> Path.join |> File.mkdir_p
      conn = conn(:propfind, "/../immoral") |> put_req_header("depth", "1") |> request(cxt)
      {403, _headers, "Forbidden"} = sent_resp(conn)
    end

    test "href values when mounted under a scope", cxt do
      scope = ["my", "dav"]
      sub = ["Some Doors", "Are Green"]
      abs_sub = [cxt.root | sub] |> Path.join
      File.mkdir_p(abs_sub)
      File.write!([abs_sub, "file.txt"] |> Path.join, "something", [:binary])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop><getcontentlength/></prop>
        </propfind>
      )
      path = ["/" | Enum.map(sub, &URI.encode/1)] |> Path.join
      scoped_path = ["/" | Enum.map(Enum.concat(scope, sub), &URI.encode/1)] |> Path.join
      conn =
        conn(:propfind, path <> "/", req)
        |> Map.put(:script_name, scope)
        |> put_req_header("depth", "1")
        |> request(cxt)

      {207, _headers, body} = sent_resp(conn)

      proplist =
        body
        |> parse_proplist

      assert length(proplist.responses) == 2
      [dir, file] = proplist.responses

      [propstat] = dir.propstat
      assert propstat.status == "HTTP/1.1 200 OK"
      assert dir.href == scoped_path <> "/"
      assert file.href == "#{scoped_path}/file.txt"
    end
  end

  describe "MKCOL" do
    test "Creates top level directory", cxt do
      path = "/Something"
      conn = conn(:mkcol, path, "") |> request(cxt)
      {201, _headers, ""} = sent_resp(conn)
      assert [cxt.root, path] |> Path.join |> File.exists?
      assert [cxt.root, path] |> Path.join |> File.dir?
    end

    test "Creates a sub-directory", cxt do
      path = "/Something/else/there/now"
      [cxt.root, "Something/else/there"] |> Path.join |> File.mkdir_p
      conn = conn(:mkcol, path, "") |> request(cxt)
      {201, _headers, ""} = sent_resp(conn)
      assert [cxt.root, path] |> Path.join |> File.exists?
      assert [cxt.root, path] |> Path.join |> File.dir?
    end

    test "Fails if a parent directory is missing", cxt do
      path = "/Something/else/there/now"
      [cxt.root, "Something/else"] |> Path.join |> File.mkdir_p
      conn = conn(:mkcol, path, "") |> request(cxt)
      {409, _headers, _body} = sent_resp(conn)
    end

    test "Prevents traversing beyond the root", cxt do
      path = "/../../../naughty-#{DateTime.utc_now |> DateTime.to_unix |> to_string}"
      assert File.dir?([cxt.root, Path.dirname(path)] |> Path.join)
      conn = conn(:mkcol, path, "") |> request(cxt)
      {403, _headers, _body} = sent_resp(conn)
      assert !File.dir?([cxt.root, path] |> Path.join |> Path.expand)
    end

    test "Errors if given a body", cxt do
      path = "/Something"
      conn = conn(:mkcol, path, "<?xml version='1.0'?>") |> request(cxt)
      {415, _headers, "Unsupported Media Type"} = sent_resp(conn)
    end
  end

  describe "PUT" do
    test "Fails if the parent directory doesn't exist", cxt do
      path = "/Something/else/there/now"
      conn = conn(:put, path, "body") |> request(cxt)
      {409, _headers, _body} = sent_resp(conn)
    end

    test "fails if PUTing to a directory", cxt do
      path = "/Something/else/there/now"
      [cxt.root, path] |> Path.join |> File.mkdir_p
      conn = conn(:put, path, "something") |> request(cxt)
      {405, _headers, _body} = sent_resp(conn)
    end

    test "fails if PUTing to root", cxt do
      conn = conn(:put, "/", "something") |> request(cxt)
      {403, _headers, _body} = sent_resp(conn)
    end

    test "protects against writes above root", cxt do
      path = "../../file.txt"
      conn = conn(:put, path, "something") |> request(cxt)
      {403, _headers, "Forbidden"} = sent_resp(conn)
    end

    test "Creates the given file", cxt do
      path = "/Something/else/there/song.mp3"
      [cxt.root, Path.dirname(path)] |> Path.join |> File.mkdir_p
      conn = conn(:put, path, "body") |> request(cxt)
      {200, _headers, _body} = sent_resp(conn)
      file = [cxt.root, path] |> Path.join
      assert File.read!(file) == "body"
    end
  end

  describe "GET" do
    test "protects against root traversal", cxt do
      path = "../../file.txt"
      conn = conn(:get, path) |> request(cxt)
      {403, _headers, "Forbidden"} = sent_resp(conn)
    end

    test "returns 404 if file doesn't exist", cxt do
      path = "/file.txt"
      conn = conn(:get, path) |> request(cxt)
      {404, _headers, "Not Found"} = sent_resp(conn)
    end

    test "streams the file if it exists", cxt do
      path = "/Something/else/there/song.mp3"
      [cxt.root, Path.dirname(path)] |> Path.join |> File.mkdir_p
      File.write!([cxt.root, path] |> Path.join, "something", [:binary])
      conn = conn(:get, path) |> request(cxt)
      {200, headers, body} = sent_resp(conn)
      [content_type] = for {k, v} <- headers, k == "content-type", do: v
      assert content_type == "audio/mpeg"
      assert body == "something"
    end

    test "returns 405 if target is a directory", cxt do
      path = "/Something/else/there"
      [cxt.root, path] |> Path.join |> File.mkdir_p
      conn = conn(:get, path) |> request(cxt)
      {405, _headers, _body} = sent_resp(conn)
    end
  end

  describe "MOVE" do
    test "Missing Destination header", cxt do
      conn = conn(:move, "/") |> request(cxt)
      {400, _headers, _body} = sent_resp(conn)
    end

    test "Valid source & destination", cxt do
      src_path = "/song.mp3"
      [cxt.root, Path.dirname(src_path)] |> Path.join |> File.mkdir_p
      File.write!([cxt.root, src_path] |> Path.join, "something", [:binary])
      dst_path = "/house.mp3"
      conn = conn(:move, src_path) |> put_req_header("destination", dst_path) |> request(cxt)
      {201, _headers, _body} = sent_resp(conn)
      assert [cxt.root, dst_path] |> Path.join |> File.exists?
      refute [cxt.root, src_path] |> Path.join |> File.exists?
      assert File.read!([cxt.root, dst_path] |> Path.join) == "something"
    end

    test "Missing parent directories for destination", cxt do
      src_path = "/song.mp3"
      [cxt.root, Path.dirname(src_path)] |> Path.join |> File.mkdir_p
      File.write!([cxt.root, src_path] |> Path.join, "something", [:binary])
      dst_path = "/missing/house.mp3"
      conn = conn(:move, src_path) |> put_req_header("destination", dst_path) |> request(cxt)
      {409, _headers, _body} = sent_resp(conn)
      refute [cxt.root, dst_path] |> Path.join |> File.exists?
      assert [cxt.root, src_path] |> Path.join |> File.exists?
    end

    test "Missing source file", cxt do
      src_path = "/missing.mp3"
      [cxt.root, Path.dirname(src_path)] |> Path.join |> File.mkdir_p
      refute [cxt.root, src_path] |> Path.join |> File.exists?
      dst_path = "/house.mp3"
      conn = conn(:move, src_path) |> put_req_header("destination", dst_path) |> request(cxt)
      {404, _headers, _body} = sent_resp(conn)
      refute [cxt.root, dst_path] |> Path.join |> File.exists?
    end

    test "Absolute URI destination", cxt do
      src_path = "/song.mp3"
      [cxt.root, Path.dirname(src_path)] |> Path.join |> File.mkdir_p
      File.write!([cxt.root, src_path] |> Path.join, "something", [:binary])
      dst_path = "/house.mp3"
      dst = "http://www.example.com#{dst_path}"
      conn = conn(:move, src_path) |> put_req_header("destination", dst) |> request(cxt)
      {201, _headers, _body} = sent_resp(conn)
      assert [cxt.root, dst_path] |> Path.join |> File.exists?
      refute [cxt.root, src_path] |> Path.join |> File.exists?
      assert File.read!([cxt.root, dst_path] |> Path.join) == "something"
    end

    test "Absolute URI destination on different host", cxt do
      src_path = "/song.mp3"
      [cxt.root, Path.dirname(src_path)] |> Path.join |> File.mkdir_p
      File.write!([cxt.root, src_path] |> Path.join, "something", [:binary])
      dst_path = "/house.mp3"
      dst = "http://www.denied.com#{dst_path}"
      conn = conn(:move, src_path) |> put_req_header("destination", dst) |> request(cxt)
      {409, _headers, _body} = sent_resp(conn)
      refute [cxt.root, dst_path] |> Path.join |> File.exists?
      assert [cxt.root, src_path] |> Path.join |> File.exists?
    end

    test "Identical source and destinations", cxt do
      src_path = "/song.mp3"
      [cxt.root, Path.dirname(src_path)] |> Path.join |> File.mkdir_p
      File.write!([cxt.root, src_path] |> Path.join, "something", [:binary])
      dst_path = "/song.mp3"
      conn = conn(:move, src_path) |> put_req_header("destination", dst_path) |> request(cxt)
      {403, _headers, _body} = sent_resp(conn)
    end

    test "URI encoded destination", cxt do
      src_path = "/song.mp3"
      [cxt.root, Path.dirname(src_path)] |> Path.join |> File.mkdir_p
      File.write!([cxt.root, src_path] |> Path.join, "something", [:binary])
      dst_path = "house home.mp3"
      conn = conn(:move, src_path) |> put_req_header("destination", "/#{URI.encode(dst_path)}") |> request(cxt)
      {201, _headers, _body} = sent_resp(conn)
      assert [cxt.root, dst_path] |> Path.join |> File.exists?
      refute [cxt.root, src_path] |> Path.join |> File.exists?
      assert File.read!([cxt.root, dst_path] |> Path.join) == "something"
    end

    test "Mounted under sub-directory", cxt do
      scope = "/collections"
      src_path = "/song.mp3"
      [cxt.root, Path.dirname(src_path)] |> Path.join |> File.mkdir_p
      File.write!([cxt.root, src_path] |> Path.join, "something", [:binary])
      dst_path = "music.mp3"
      destination = Path.join([scope, dst_path])
      conn = conn(:move, src_path) |> Map.put(:script_name, ["collections"]) |> put_req_header("destination", destination) |> request(cxt)
      {201, _headers, _body} = sent_resp(conn)
      assert [cxt.root, dst_path] |> Path.join |> File.exists?
      refute [cxt.root, src_path] |> Path.join |> File.exists?
      assert File.read!([cxt.root, dst_path] |> Path.join) == "something"
    end
  end

  describe "DELETE" do
    test "file", cxt do
      path = "/file.txt"
      File.write!([cxt.root, path] |> Path.join, "something", [:binary])
      conn = conn(:delete, path) |> request(cxt)
      {204, _headers, ""} = sent_resp(conn)
      refute [cxt.root, path] |> Path.join |> File.exists?
    end

    test "directory", cxt do
      paths = [
        "/something/else/here.mp3",
        "/something/here.mp3",
      ]
      Enum.each(paths, fn path ->
        [cxt.root, Path.dirname(path)] |> Path.join |> File.mkdir_p
        [cxt.root, path] |> Path.join |> File.write!(path, [:binary])
      end)
      conn = conn(:delete, "/something") |> request(cxt)
      {204, _headers, ""} = sent_resp(conn)
      Enum.each(paths, fn path ->
        refute [cxt.root, Path.dirname(path)] |> Path.join |> File.exists?
        refute [cxt.root, path] |> Path.join |> File.exists?
      end)
    end

    test "traversing root directory", cxt do
      conn = conn(:delete, "/../..") |> request(cxt)
      {403, _headers, "Forbidden"} = sent_resp(conn)
    end
  end

  describe "LOCK" do
    test "PROPFIND supportedlock", cxt do
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop>
            <supportedlock/>
          </prop>
        </propfind>
      )
      conn = conn(:propfind, "/", req) |> put_req_header("depth", "0") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)
      doc = body |> parse_response
      [:xmlElement, :"d:exclusive" | _] = SweetXml.xpath(doc, xpath("//d:response/d:propstat/d:prop/d:supportedlock/d:lockentry/d:lockscope/d:exclusive")) |> Tuple.to_list
      [:xmlElement, :"d:write" | _] = SweetXml.xpath(doc, xpath("//d:response/d:propstat/d:prop/d:supportedlock/d:lockentry/d:locktype/d:write")) |> Tuple.to_list
    end
    test "PROPFIND lockdiscovery (no locks)", cxt do
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop>
            <lockdiscovery/>
          </prop>
        </propfind>
      )
      conn = conn(:propfind, "/", req) |> put_req_header("depth", "0") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)
      doc = body |> parse_response
      assert nil == SweetXml.xpath(doc, xpath("//d:response/d:propstat/d:prop/d:lockdiscovery/*"))
    end

    test "PROPFIND lockdiscovery", cxt do
      require SweetXml
      {:ok, lock} = Lock.acquire_exclusive(cxt.root, [])
      req = ~s(<?xml version="1.0" encoding="UTF-8"?>
        <propfind xmlns="DAV:">
          <prop>
            <lockdiscovery/>
          </prop>
        </propfind>
      )
      conn = conn(:propfind, "/", req) |> put_req_header("depth", "0") |> request(cxt)
      {207, _headers, body} = sent_resp(conn)
      doc = body |> parse_response
      [l] = SweetXml.xpath(
        doc,
        xpath("//d:response/d:propstat/d:prop/d:lockdiscovery/d:activelock", 'l'),
        locktype: xpath("./d:locktype/*", 'l'),
        lockscope: xpath("./d:lockscope/*", 'l'),
        lockdepth: xpath("./d:depth/text()", 's'),
        locktimeout: xpath("./d:timeout/text()", 's'),
        id: xpath("./d:locktoken/d:href/text()", 's'),
      )
      assert l.id == lock.id
      assert l.lockdepth == "Infinity"
      assert l.locktimeout == "Second-3600"
      [type] = l.locktype
      assert :"d:write" == SweetXml.xmlElement(type, :name)
      [scope] = l.lockscope
      assert :"d:exclusive" == SweetXml.xmlElement(scope, :name)
    end

    test "LOCK / depth: infinity", cxt do
      req = [
        ~s(<?xml version="1.0" encoding="UTF-8"?>),
        ~s(<lockinfo xmlns="DAV:">),
        "<lockscope><exclusive/></lockscope>",
        "<locktype><write/></locktype>",
        # <d:owner>
        #      <d:href>http://www.ics.uci.edu/~ejw/contact.html</d:href>
        # </d:owner>
        "</lockinfo>",
      ] |> IO.iodata_to_binary
      conn = conn(:lock, "/", req) |> request(cxt)
      {200, headers, body} = sent_resp(conn)
      [lock] = Lock.all()
      assert lock.path == "/"
      assert lock.depth == :infinity
      expected = [
        ~s(<?xml version="1.0" encoding="utf-8"?>),
        ~s(<d:prop xmlns:d="DAV:">),
        ~s(<d:lockdiscovery xmlns:d="DAV:">),
        "<d:activelock>",
        "<d:locktype><d:write/></d:locktype>",
        "<d:lockscope><d:exclusive/></d:lockscope>",
        "<d:depth>Infinity</d:depth>",
        # "<d:owner>",
        #      "<d:href>",
        #           "http://www.ics.uci.edu/~ejw/contact.html",
        #      "</d:href>",
        # "</d:owner>",
        "<d:timeout>Second-3600</d:timeout>",
        "<d:locktoken>",
        "<d:href>",
        lock.id,
        "</d:href>",
        "</d:locktoken>",
        "</d:activelock>",
        "</d:lockdiscovery>",
        "</d:prop>",
      ] |> IO.iodata_to_binary
      assert expected == IO.iodata_to_binary(body)
      {"lock-token", lock_id} = List.keyfind(headers, "lock-token", 0)
      assert lock_id == "<#{lock.id}>"
    end

    test "LOCK / depth: 0", cxt do
      req = [
        ~s(<?xml version="1.0" encoding="UTF-8"?>),
        ~s(<lockinfo xmlns="DAV:">),
        "<lockscope><exclusive/></lockscope>",
        "<locktype><write/></locktype>",
        # <d:owner>
        #      <d:href>http://www.ics.uci.edu/~ejw/contact.html</d:href>
        # </d:owner>
        "</lockinfo>",
      ] |> IO.iodata_to_binary
      conn = conn(:lock, "/", req) |> put_req_header("depth", "0") |> request(cxt)
      {200, _headers, body} = sent_resp(conn)
      [lock] = Lock.all()
      assert lock.path == "/"
      assert lock.depth == 0
      expected = [
        ~s(<?xml version="1.0" encoding="utf-8"?>),
        ~s(<d:prop xmlns:d="DAV:">),
        ~s(<d:lockdiscovery xmlns:d="DAV:">),
        "<d:activelock>",
        "<d:locktype><d:write/></d:locktype>",
        "<d:lockscope><d:exclusive/></d:lockscope>",
        "<d:depth>0</d:depth>",
        # "<d:owner>",
        #      "<d:href>",
        #           "http://www.ics.uci.edu/~ejw/contact.html",
        #      "</d:href>",
        # "</d:owner>",
        "<d:timeout>Second-3600</d:timeout>",
        "<d:locktoken>",
        "<d:href>",
        lock.id,
        "</d:href>",
        "</d:locktoken>",
        "</d:activelock>",
        "</d:lockdiscovery>",
        "</d:prop>",
      ] |> IO.iodata_to_binary
      assert expected == IO.iodata_to_binary(body)
    end

    test "LOCK /something timeout: custom", cxt do
      req = [
        ~s(<?xml version="1.0" encoding="UTF-8"?>),
        ~s(<lockinfo xmlns="DAV:">),
        "<lockscope><exclusive/></lockscope>",
        "<locktype><write/></locktype>",
        # <d:owner>
        #      <d:href>http://www.ics.uci.edu/~ejw/contact.html</d:href>
        # </d:owner>
        "</lockinfo>",
      ] |> IO.iodata_to_binary
      conn =
        conn(:lock, "/something", req)
        |> put_req_header("timeout", "Infinite, Second-4100000000")
        |> put_req_header("depth", "0")
        |> request(cxt)
      {200, _headers, body} = sent_resp(conn)
      [lock] = Lock.all()
      assert lock.path == "/something"
      assert lock.depth == 0
      expected = [
        ~s(<?xml version="1.0" encoding="utf-8"?>),
        ~s(<d:prop xmlns:d="DAV:">),
        ~s(<d:lockdiscovery xmlns:d="DAV:">),
        "<d:activelock>",
        "<d:locktype><d:write/></d:locktype>",
        "<d:lockscope><d:exclusive/></d:lockscope>",
        "<d:depth>0</d:depth>",
        # "<d:owner>",
        #      "<d:href>",
        #           "http://www.ics.uci.edu/~ejw/contact.html",
        #      "</d:href>",
        # "</d:owner>",
        "<d:timeout>Second-4100000000</d:timeout>",
        "<d:locktoken>",
        "<d:href>",
        lock.id,
        "</d:href>",
        "</d:locktoken>",
        "</d:activelock>",
        "</d:lockdiscovery>",
        "</d:prop>",
      ] |> IO.iodata_to_binary
      assert expected == IO.iodata_to_binary(body)
    end

    test "UNLOCK", cxt do
      req = [
        ~s(<?xml version="1.0" encoding="UTF-8"?>), ~s(<lockinfo xmlns="DAV:">),
        "<lockscope><exclusive/></lockscope>", "<locktype><write/></locktype>", "</lockinfo>",
      ] |> IO.iodata_to_binary
      conn =
        conn(:lock, "/something", req)
        |> request(cxt)
      {200, headers, _body} = sent_resp(conn)
      [lock] = Lock.all()
      assert lock.path == "/something"
      {"lock-token", lock_token} = List.keyfind(headers, "lock-token", 0)
      assert lock_token == "<#{lock.id}>"
      conn =
        conn(:unlock, "/something", req)
        |> put_req_header("lock-token", lock_token)
        |> request(cxt)
      {204, _headers, ""} = sent_resp(conn)
      [] = Lock.all()
    end

    test "UNLOCK with incorrect lock id", cxt do
      req = [
        ~s(<?xml version="1.0" encoding="UTF-8"?>), ~s(<lockinfo xmlns="DAV:">),
        "<lockscope><exclusive/></lockscope>", "<locktype><write/></locktype>", "</lockinfo>",
      ] |> IO.iodata_to_binary
      conn =
        conn(:lock, "/something", req)
        |> request(cxt)
      {200, headers, _body} = sent_resp(conn)
      [lock] = Lock.all()
      assert lock.path == "/something"
      {"lock-token", lock_token} = List.keyfind(headers, "lock-token", 0)
      assert lock_token == "<#{lock.id}>"

      conn =
        conn(:unlock, "/something", req)
        |> request(cxt)
      {409, _headers, _body} = sent_resp(conn)
      [^lock] = Lock.all()

      conn =
        conn(:unlock, "/something", req)
        |> put_req_header("lock-token", "<something:wrong>")
        |> request(cxt)
      {409, _headers, _body} = sent_resp(conn)
      [^lock] = Lock.all()
    end
  end
end
