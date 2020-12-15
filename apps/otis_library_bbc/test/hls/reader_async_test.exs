defmodule HLS.ReaderAsyncTest.ErroringReader do
  defstruct []
end

defimpl HLS.Reader, for: HLS.ReaderAsyncTest.ErroringReader do
  def read(_reader, _url) do
    Process.sleep(10)
    raise("an error")
  end
end

defmodule HLS.ReaderAsyncTest do
  use ExUnit.Case, async: true

  setup do
    root = __DIR__ |> Path.join("../fixtures/hls_stream") |> Path.expand()
    reader = HLS.Reader.Dir.new(root)
    {:ok, root: root, reader: reader}
  end

  def fingerprint(data) do
    :crypto.hash_init(:md5)
    |> :crypto.hash_update(data)
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  test "it can read the given file when given a url", context do
    {:ok, _pid} =
      HLS.Reader.Async.read(
        context.reader,
        "http://something.io/high/226201867.ts",
        self(),
        :test
      )

    assert_receive {:test, {:ok, _body, _headers}}
  end

  test "it returns an error message rather than crashing" do
    {:ok, _pid} =
      HLS.Reader.Async.read(
        %HLS.ReaderAsyncTest.ErroringReader{},
        "http://something.io/high/226201867.ts",
        self(),
        :test
      )

    assert_receive {:test, {:error, _msg}}, 2_000
  end
end
