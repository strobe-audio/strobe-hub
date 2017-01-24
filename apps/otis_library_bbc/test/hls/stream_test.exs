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
end
