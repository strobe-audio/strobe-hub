defmodule M3.PlaylistTest do
  use ExUnit.Case, async: true

  setup do
    base = Path.expand("../fixtures/hls_stream", __DIR__)
    {:ok, base: base}
  end

  test "can provide the next set of media based on media sequence numbers", context do
    [segment0, segment1, segment2, segment3] = Enum.map(0..3, fn(n) ->
      [context.base, "high/segment-#{n}.m3u8"]
      |> Path.join
      |> File.read!
      |> M3.Parser.parse!("http://hlsstream.io/something/stream/high.m3u8")
    end)

    {:ok, media} = M3.Playlist.sequence(segment0, segment0)
    assert media == []

    {:ok, media} = M3.Playlist.sequence(segment1, segment0)
    assert media == [
      %M3.Media{duration: 6, filename: "no desc", url: "http://hlsstream.io/something/stream/226201869.ts"}
    ]

    {:ok, media} = M3.Playlist.sequence(segment2, segment1)
    assert media == [
      %M3.Media{duration: 6, filename: "no desc", url: "http://hlsstream.io/something/stream/226201870.ts"}
    ]

    {:ok, media} = M3.Playlist.sequence(segment3, segment2)
    assert media == [
      %M3.Media{duration: 6, filename: "no desc", url: "http://hlsstream.io/something/stream/226201871.ts"},
      %M3.Media{duration: 6, filename: "no desc", url: "http://hlsstream.io/something/stream/226201872.ts"},
    ]
  end

  test "handles out-of-sequence playlists", context do
    [segment0, segment1] = Enum.map(0..1, fn(n) ->
      [context.base, "high/segment-#{n}.m3u8"]
      |> Path.join
      |> File.read!
      |> M3.Parser.parse!("http://hlsstream.io/something/stream/high.m3u8")
    end)

    {:ok, media} = M3.Playlist.sequence(segment0, segment1)
    assert media == []
  end
end
