defmodule HLS.ProgrammableReaderTest do
  use ExUnit.Case, async: true

  setup do
    root = __DIR__ |> Path.join("../fixtures/hls_stream") |> Path.expand()
    {:ok, root: root}
  end

  def fingerprint({:ok, data, _headers}) do
		fingerprint(data)
	end
  def fingerprint(data) do
    :crypto.hash_init(:md5)
    |> :crypto.hash_update(data)
    |> :crypto.hash_final
    |> Base.encode16(case: :lower)
  end

  test "it can read the given file", context do
    reader = HLS.Reader.Programmable.new(context.root, %{})
    md5 = HLS.Reader.read(reader, "http://something.io/high/226201867.ts") |> fingerprint
    assert md5 == "c96820e0b3af1e34b8a368a23b097a57"
  end

  test "it can override particular urls with a sequence", context do
    urls = %{"/high/segment.m3u8" => [
      "/high/segment-0.m3u8",
      "/high/segment-1.m3u8",
      "/high/segment-2.m3u8",
      "/high/segment-3.m3u8",
    ]}
    reader = HLS.Reader.Programmable.new(context.root, urls)
    md5 = HLS.Reader.read(reader, "http://something.io/high/226201867.ts") |> fingerprint
    assert md5 == "c96820e0b3af1e34b8a368a23b097a57"

    {:ok, playlist, _headers} = HLS.Reader.read(reader, "http://something.io/high/segment.m3u8")
    assert playlist == File.read!(Path.join([context.root, "/high/segment-0.m3u8"]))
    {:ok, playlist, _headers} = HLS.Reader.read(reader, "http://something.io/high/segment.m3u8")
    assert playlist == File.read!(Path.join([context.root, "/high/segment-1.m3u8"]))
    {:ok, playlist, _headers} = HLS.Reader.read(reader, "http://something.io/high/segment.m3u8")
    assert playlist == File.read!(Path.join([context.root, "/high/segment-2.m3u8"]))
    {:ok, playlist, _headers} = HLS.Reader.read(reader, "http://something.io/high/segment.m3u8")
    assert playlist == File.read!(Path.join([context.root, "/high/segment-3.m3u8"]))
    {:ok, playlist, _headers} = HLS.Reader.read(reader, "http://something.io/high/segment.m3u8")
    assert playlist == File.read!(Path.join([context.root, "/high/segment-3.m3u8"]))
  end
end
