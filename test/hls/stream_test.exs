defmodule HLS.StreamTest do
  use ExUnit.Case, async: true
  doctest HLS.Stream

  alias HLS.Stream

  setup do
    root = __DIR__ |> Path.join("../fixtures/hls_stream") |> Path.expand()
    reader = HLS.Reader.Dir.new(root)
    m3 = [root, "radio4_master.m3u8"] |> Path.join |> File.read!
    playlist = M3.Parser.parse!(m3, "http://bbc.io/radio4_master.m3u8")
    stream = HLS.Stream.new(playlist, reader)
    {:ok, stream: stream, root: root}
  end

  test "returns the highest & lowest bandwidth variants", context do
    data = Stream.highest(context.stream)
    assert %{ url: "http://bbc.io/radio4_high.m3u8", bandwidth: 339200} == Map.take(data, [:url, :bandwidth])

    data = Stream.lowest(context.stream)
    assert %{ url: "http://bbc.io/radio4_low.m3u8", bandwidth: 101760} == Map.take(data, [:url, :bandwidth])
  end

  test "can provide the next lowest bandwidth stream", context do
    data = Stream.highest(context.stream)
    data = Stream.downgrade(context.stream, data)
    assert %{ url: "http://bbc.io/radio4_med.m3u8", bandwidth: 135680} == Map.take(data, [:url, :bandwidth])
    data = Stream.downgrade(context.stream, data)
    assert %{ url: "http://bbc.io/radio4_low.m3u8", bandwidth: 101760} == Map.take(data, [:url, :bandwidth])
    data = Stream.downgrade(context.stream, data)
    assert %{ url: "http://bbc.io/radio4_low.m3u8", bandwidth: 101760} == Map.take(data, [:url, :bandwidth])
  end

  test "can provide the next highest bandwidth stream", context do
    data = Stream.lowest(context.stream)
    data = Stream.upgrade(context.stream, data)
    assert %{ url: "http://bbc.io/radio4_med.m3u8", bandwidth: 135680} == Map.take(data, [:url, :bandwidth])
    data = Stream.upgrade(context.stream, data)
    assert %{ url: "http://bbc.io/radio4_high.m3u8", bandwidth: 339200} == Map.take(data, [:url, :bandwidth])
    data = Stream.upgrade(context.stream, data)
    assert %{ url: "http://bbc.io/radio4_high.m3u8", bandwidth: 339200} == Map.take(data, [:url, :bandwidth])
  end

  test "can resolve a variant playlist to a live one", context do
    playlist = Stream.resolve(context.stream)
    assert to_string(playlist.uri) == "http://bbc.io/high/segment.m3u8"
    [file | _] = playlist.media
    assert %M3.Media{ duration: 6, filename: "no desc", url: "http://bbc.io/high/226201865.ts"} == file
  end

  test "returns a valid data stream", context do
    files = Enum.map ~w[226201865.ts 226201866.ts 226201867.ts 226201868.ts], fn(filename) ->
      [context.root, "high", filename] |> Path.join |> File.read!
    end
    stream = Stream.open!(context.stream)
    data = Enum.take(stream, 4)
    assert data == files
  end

  test "keeps reloading the playlist file", context do
    names =  Enum.map 226201865..226201873, fn(id) -> "#{id}.ts" end
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
    stream = Stream.open!(hls)
    data = Enum.take(stream, length(files))
    assert data == files
  end

  test "ignores playlists with duplicate sequence ids", context do
    names =  Enum.map 226201865..226201873, fn(id) -> "#{id}.ts" end
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
    stream = Stream.open!(hls)
    data = Enum.take(stream, length(files))
    assert data == files
  end
end
