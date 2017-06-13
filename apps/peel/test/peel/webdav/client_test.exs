defmodule Peel.WebDAV.ClientTest do
  use ExUnit.Case
  use Plug.Test

  alias Peel.Collection

  # require Handler
  @classify Peel.WebDAV.Classifier
  @webdav  Plug.WebDAV.Handler
  @handler Peel.WebDAV.Events

  @collections [
    "Collection 1",
    "Collection 2",
  ]

  @silent_path [__DIR__, "../../fixtures/music/silent.mp3"] |> Path.join
  @silence File.read!(@silent_path)

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Peel.Repo)


    config = Application.get_env :peel, Peel.Collection

    File.mkdir_p(config[:root])

    collections = Enum.map(@collections, &Collection.create(&1, config[:root]))
    Enum.each(@collections, &File.mkdir_p([config[:root], &1] |> Path.join))

    on_exit fn ->
      File.rm_rf(config[:root])
    end

    TestEventHandler.attach([Peel.WebDAV.Modifications])

    {:ok, root: config[:root], collections: collections, opts: @handler.init(config)}
  end

  def call(conn, opts) do
    conn |> @classify.call(opts) |> @webdav.call(opts) |> @handler.call(opts)
  end

  def request(method, path, headers \\ [], cxt) do
    conn(method, path)
    |> merge_req_headers(headers)
    |> call(cxt.opts)
  end

  def merge_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn({k, v}, conn) -> put_req_header(conn, k, v) end)
  end

  test "MKCOL /New Collection", cxt do
    conn = request("MKCOL",  "/New Collection", cxt)
    {201, _headers, _body} = sent_resp(conn)
    assert_receive {:modification, {:create, [:collection, "New Collection"]}}, 500
    assert_receive {:complete, {:create, [:collection, "New Collection"]}}, 500
    {:ok, %Collection{name: "New Collection"} = collection} = Collection.from_name("New Collection")
    assert collection.path == [cxt[:root], "New Collection"] |> Path.join
    assert collection.path |> File.dir?()
  end

  test "MKCOL /New%20Collection", cxt do
    conn = request("MKCOL",  "/New%20Collection", cxt)
    {201, _headers, _body} = sent_resp(conn)
    assert_receive {:modification, {:create, [:collection, "New Collection"]}}, 500
    assert_receive {:complete, {:create, [:collection, "New Collection"]}}, 500
    {:ok, %Collection{name: "New Collection"} = collection} = Collection.from_name("New Collection")
    assert collection.path == [cxt[:root], "New Collection"] |> Path.join
    assert collection.path |> File.dir?()
  end

  test "MKCOL /Collection 1/New Artist", cxt do
    path = "/Collection 1/New Artist"
    conn = request("MKCOL", path, cxt)
    {201, _headers, _body} = sent_resp(conn)
    refute_receive {:modification, {:create, [_type, ^path]}}, 500
    assert [cxt[:root], path] |> Path.join |> File.dir?
  end

  @tag :capture_log  # swallow error messages when importing file with no metadata
  test "PUT /Collection 1/Artist Name/Album Name/Track Name.mp3", cxt do
    path =  "/Collection 1/Artist Name/Album Name/Track Name.mp3"
    [cxt[:root], Path.dirname(path)] |> Path.join |> File.mkdir_p
    conn =
      conn("PUT", path, @silence)
      |> merge_req_headers([{"content-type", "audio/mpeg"}])
      |> call(cxt.opts)
    {200, _headers, _body} = sent_resp(conn)
    assert_receive {:modification, {:create, [:file, ^path]}}, 500
    assert_receive {:complete, {:create, [:file, ^path]}}, 500
    assert [cxt[:root], path] |> Path.join |> File.exists?
  end

  test "PUT /Collection 1/Artist Name/Album Name/Track Name.mp3 => 409", cxt do
    path =  "/Collection 1/Artist Name/Album Name/Track Name.mp3"
    conn =
      conn("PUT", path, @silence)
      |> merge_req_headers([{"content-type", "audio/mpeg"}])
      |> call(cxt.opts)
    {409, _headers, _body} = sent_resp(conn)
    refute_receive {:modification, {:create, [_type, ^path]}}, 500
  end

  test "MOVE /Collection 1/Artist Name/Album Name/Track Name.mp3", cxt do
    path =  "/Collection 1/Artist Name/Album Name/Track Name.mp3"
    [cxt[:root], Path.dirname(path)] |> Path.join |> File.mkdir_p
    File.cp!(@silent_path, [cxt[:root], path] |> Path.join)
    new_path = "/Collection 1/Other Artist/Other Album/Track Name.mp3"
    [cxt[:root], Path.dirname(new_path)] |> Path.join |> File.mkdir_p
    conn = request("MOVE", path, [{"destination", new_path}], cxt)
    {201, _headers, _body} = sent_resp(conn)
    assert_receive {:modification, {:move, [:file, ^path, ^new_path]}}, 500
  end

  test "MOVE /Collection 1/Artist Name/Album Name", cxt do
    path =  "/Collection 1/Artist Name/Album Name"
    [cxt[:root], path] |> Path.join |> File.mkdir_p
    new_path = "/Collection 1/Artist Name/Other Album"
    conn = request("MOVE", path, [{"destination", new_path}], cxt)
    {201, _headers, _body} = sent_resp(conn)
    assert_receive {:modification, {:move, [:directory, ^path, ^new_path]}}, 500
  end

  test "DELETE /Collection 1/Artist Name/Album Name/Track Name.mp3", cxt do
    path =  "/Collection 1/Artist Name/Album Name/Track Name.mp3"
    [cxt[:root], Path.dirname(path)] |> Path.join() |> File.mkdir_p()
    File.cp!(@silent_path, [cxt[:root], path] |> Path.join)

    conn = request("DELETE", path, cxt)
    {204, _headers, ""} = sent_resp(conn)
    assert_receive {:modification, {:delete, [:file, ^path]}}, 500
  end

  test "DELETE /Collection 1/Artist Name", cxt do
    path =  "/Collection 1/Artist Name"
    [cxt[:root], path] |> Path.join() |> File.mkdir_p()

    conn = request("DELETE", path, cxt)
    {204, _headers, ""} = sent_resp(conn)
    assert_receive {:modification, {:delete, [:directory, ^path]}}, 500
  end
end
