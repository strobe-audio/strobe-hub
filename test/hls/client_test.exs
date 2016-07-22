defmodule HLS.ClientTest do
  use ExUnit.Case, async: true

  alias HLS.Client

  setup do
    root = __DIR__ |> Path.join("../fixtures/hls_stream") |> Path.expand()
    reader = HLS.Reader.Dir.new(root)
    m3 = [root, "radio4_master.m3u8"] |> Path.join |> File.read!
    playlist = M3.Parser.parse!(m3, "http://bbc.io/radio4_master.m3u8")
    stream = HLS.Stream.new(playlist, reader)
    {:ok, stream: stream, root: root}
  end


  test "returns a valid data stream", context do
    files = Enum.map ~w[226201865.ts 226201866.ts 226201867.ts 226201868.ts], fn(filename) ->
      [context.root, "high", filename] |> Path.join |> File.read!
    end
    {:ok, stream} = Client.open!(context.stream, "stream-1")
    data = Enum.take(stream, 4)
    assert data == files
  end

  test "keeps reloading the playlist file", context do
    names =  Enum.map 226201865..226201872, fn(id) -> "#{id}.ts" end
    files = Enum.map names, fn(filename) ->
      [context.root, "high", filename] |> Path.join |> File.read!
    end
    m3 = [context.root, "high.m3u8"] |> Path.join |> File.read!
    playlist = M3.Parser.parse!(m3, "http://bbc.io/high.m3u8")
    urls = %{"/high/segment.m3u8" => [
      "/high/segment-0.m3u8",
      "/high/segment-1.m3u8",
      "/high/segment-2.m3u8",
      "/high/segment-3.m3u8",
    ]}
    reader = HLS.Reader.Programmable.new(context.root, urls)
    hls = HLS.Stream.new(playlist, reader)
    {:ok, stream} = Client.open!(hls, "stream-2")
    data = Enum.take(stream, length(files))
    assert data == files
  end

  test "ignores playlists with duplicate sequence ids", context do
    names =  Enum.map 226201865..226201872, fn(id) -> "#{id}.ts" end
    files = Enum.map names, fn(filename) ->
      [context.root, "high", filename] |> Path.join |> File.read!
    end
    m3 = [context.root, "high.m3u8"] |> Path.join |> File.read!
    playlist = M3.Parser.parse!(m3, "http://bbc.io/high.m3u8")
    urls = %{"/high/segment.m3u8" => [
      "/high/segment-0.m3u8",
      "/high/segment-0.m3u8",
      "/high/segment-1.m3u8",
      "/high/segment-1.m3u8",
      "/high/segment-2.m3u8",
      "/high/segment-2.m3u8",
      "/high/segment-3.m3u8",
    ]}
    reader = HLS.Reader.Programmable.new(context.root, urls)
    hls = HLS.Stream.new(playlist, reader)
    {:ok, stream}{:ok, stream} Client.open!(hls, "stream-3")
    data = Enum.take(stream, length(files))
    assert data == files
  end
end

