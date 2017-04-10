defmodule HLS.DirReaderTest do
  use ExUnit.Case, async: true

  setup do
    root = __DIR__ |> Path.join("../fixtures/hls_stream") |> Path.expand()
    reader = HLS.Reader.Dir.new(root)
    {:ok, root: root, reader: reader}
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

  test "it can read the given file when given a url", context do
    md5 = HLS.Reader.read(context.reader, "http://something.io/high/226201867.ts") |> fingerprint
    assert md5 == "c96820e0b3af1e34b8a368a23b097a57"
  end

  test "it can read the given file when given a path", context do
    md5 = HLS.Reader.read(context.reader, "/high/226201867.ts") |> fingerprint
    assert md5 == "c96820e0b3af1e34b8a368a23b097a57"
  end
end
