defmodule M3.ParserTest do
  use ExUnit.Case, async: true

  setup do
    base = Path.expand("../fixtures/hls_stream", __DIR__)
    high = [base, "high.m3u8"] |> Path.join() |> File.read!()
    segment = [base, "high/segment.m3u8"] |> Path.join() |> File.read!()
    {:ok, base: base, high: high, segment: segment}
  end

  test "it extracts the stream version", context do
    playlist = M3.Parser.parse!(context.high, "http://hlsstream.io/something/stream/high.m3u8")
    assert playlist.version == 2
  end

  test "it extracts the media urls", context do
    playlist = M3.Parser.parse!(context.high, "http://hlsstream.io/something/stream/high.m3u8")
    assert URI.to_string(playlist.uri) == "http://hlsstream.io/something/stream/high.m3u8"
    assert M3.Playlist.Variant == playlist.__struct__

    assert playlist.media == [
             %M3.Variant{
               url: "http://hlsstream.io/something/stream/high/segment.m3u8",
               bandwidth: 339_200,
               codecs: [["mp4a", "40.2"]],
               program_id: "1"
             },
             %M3.Variant{
               url: "http://hlsstream.io/something/stream/med/segment.m3u8",
               bandwidth: 135_680,
               codecs: [["mp4a", "40.2"]],
               program_id: "1"
             },
             %M3.Variant{
               url: "http://hlsstream.io/something/stream/low/segment.m3u8",
               bandwidth: 101_760,
               codecs: [["mp4a", "40.2"]],
               program_id: "1"
             }
           ]
  end

  test "it can resolve a variant playlist to a live playlist", context do
    playlist = M3.Parser.parse!(context.high, "http://hlsstream.io/something/stream/high.m3u8")
    assert playlist.version == 2

    variant = M3.Playlist.variant(playlist)

    assert variant == %M3.Variant{
             url: "http://hlsstream.io/something/stream/high/segment.m3u8",
             bandwidth: 339_200,
             codecs: [["mp4a", "40.2"]],
             program_id: "1"
           }

    # variant = M3.Playlist.variant(codecs: ["mp4"], bandwidth: :highest)
    # assert variant == %M3.Variant{url: "http://hlsstream.io/something/stream/high/segment.m3u8", bandwidth: 339200, codecs: [["mp4a", "40.2"]], program_id: "1"}
    #
    # variant = M3.Playlist.variant(codecs: ["mp4"], bandwidth: :lowest)
    # assert variant == %M3.Variant{url: "http://hlsstream.io/something/stream/low/segment.m3u8", bandwidth: 101760, codecs: [["mp4a", "40.2"]], program_id: "1"}
  end

  test "it extracts the media urls & metadata", context do
    playlist =
      M3.Parser.parse!(context.segment, "http://hlsstream.io/something/stream/high/segment.m3u8")

    assert playlist.__struct__ == M3.Playlist.Live
    assert playlist.media_sequence_number == 226_201_865
    assert playlist.target_duration == 7

    assert playlist.media == [
             %M3.Media{
               url: "http://hlsstream.io/something/stream/high/226201865.ts",
               duration: 6,
               filename: "no desc"
             },
             %M3.Media{
               url: "http://hlsstream.io/something/stream/high/226201866.ts",
               duration: 6,
               filename: "no desc"
             },
             %M3.Media{
               url: "http://hlsstream.io/something/stream/high/226201867.ts",
               duration: 6,
               filename: "no desc"
             },
             %M3.Media{
               url: "http://hlsstream.io/something/stream/high/226201868.ts",
               duration: 6,
               filename: "no desc"
             }
           ]
  end
end
