defmodule TestUtils do
  def md5(extract) do
    md5(extract, :crypto.hash_init(:md5))
  end

  defp md5(extract, md5) do
    _md5(extract.(), extract, md5)
  end

  defp _md5({:ok, data}, extract, md5) do
    _md5(extract.(), extract, :crypto.hash_update(md5, data))
  end

  defp _md5(:stopped, _extract, md5) do
    :crypto.hash_final(md5) |> Base.encode16 |> String.downcase
  end

  defp _md5(:done, _extract, md5) do
    :crypto.hash_final(md5) |> Base.encode16 |> String.downcase
  end

  def acc_stream(stream) do
    acc_stream(stream, <<>>)
  end

  defp acc_stream(stream, acc) do
    _acc_stream(stream, Otis.AudioStream.frame(stream), acc)
  end

  defp _acc_stream(stream, {:ok, data}, acc) do
    _acc_stream(stream, Otis.AudioStream.frame(stream), << acc <> data >>)
  end

  defp _acc_stream(_stream, :stopped, acc) do
    acc
  end
end

defmodule OtisTest do
  use ExUnit.Case

  test "opening silent mp3 should give a data stream of all 0" do
    {:ok, source} = Otis.Source.File.from_path("test/fixtures/silent.mp3")
    {:ok, pcm } = Otis.Source.chunk source
    assert byte_size(pcm) == 4608

    Enum.each :binary.bin_to_list(pcm), fn(b) ->
      assert b == 0
    end

    result = Otis.Source.chunk source
    assert result == :done
  end

  test "opening streaming mp3 should give a valid PCM data stream" do
    {:ok, source} = Otis.Source.File.from_path("test/fixtures/snake-rag.mp3")
    hash = TestUtils.md5 fn() -> Otis.Source.chunk(source) end
    # sox test/fixtures/snake-rag.mp3  --type raw --bits 16 --channels 2 --endian little --rate 44100 --encoding signed-integer - | md5
    assert hash == "7f022a83734ed280feed7577e2522490"
  end
end

defmodule Otis.SourceStreamTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, a } = Otis.Source.File.from_path("test/fixtures/a.mp3")
    {:ok, b } = Otis.Source.File.from_path("test/fixtures/b.mp3")
    {:ok, source_stream} = Otis.SourceStream.Array.from_list([a, b])
    {:ok, source_stream: source_stream}
  end

  test "array sources should iterate the array", %{source_stream: source_stream} do

    {:ok, source} = Otis.SourceStream.next(source_stream)
    {:ok, %{path: path} = _info} = Otis.Source.info(source)
    assert path == "test/fixtures/a.mp3"

    {:ok, source} = Otis.SourceStream.next(source_stream)
    {:ok, %{path: path} = _info} = Otis.Source.info(source)
    assert path == "test/fixtures/b.mp3"

    result = Otis.SourceStream.next(source_stream)
    assert result == :done
  end
end

defmodule Otis.AudioStreamSingleTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, source} = Otis.Source.File.from_path("test/fixtures/silent.mp3")
    {:ok, source_stream} = Otis.SourceStream.Array.from_list([source])
    {:ok, audio_stream} = Otis.AudioStream.start_link(source_stream, 200)
    {:ok, audio_stream: audio_stream, chunk_size: 200, source_stream: source_stream}
  end

  test "source list", %{audio_stream: audio_stream, chunk_size: chunk_size} do
    Enum.each 0..22, fn(_) ->
      { :ok, frame } = Otis.AudioStream.frame(audio_stream)
      assert byte_size(frame) == chunk_size
    end
    {:ok, frame} = Otis.AudioStream.frame(audio_stream)
    assert byte_size(frame) == 4608 - (23*chunk_size)
    result = Otis.AudioStream.frame(audio_stream)
    assert result == :stopped
  end

  test "adding a source after finishing the first", %{audio_stream: audio_stream, chunk_size: chunk_size, source_stream: source_stream} do
    Enum.each 0..22, fn(_) ->
      { :ok, _frame } = Otis.AudioStream.frame(audio_stream)
    end
    {:ok, _frame} = Otis.AudioStream.frame(audio_stream)
    result = Otis.AudioStream.frame(audio_stream)
    assert result == :stopped
    {:ok, source} = Otis.Source.File.from_path("test/fixtures/silent.mp3")
    :ok = Otis.SourceStream.append_source(source_stream, source)
    Enum.each 0..22, fn(_) ->
      { :ok, frame } = Otis.AudioStream.frame(audio_stream)
      assert byte_size(frame) == chunk_size
    end
    {:ok, frame} = Otis.AudioStream.frame(audio_stream)
    assert byte_size(frame) == 4608 - (23*chunk_size)
  end
end

defmodule Otis.AudioStreamMultipleTest do
  use ExUnit.Case, async: true

  setup do
    paths = [
      "test/fixtures/snake-rag.mp3",
      "test/fixtures/silent.mp3",
      "test/fixtures/snake-rag.mp3"
    ]
    ss  = Enum.map paths, fn(path) ->
      {:ok, source } = Otis.Source.File.from_path(path)
      source
    end
    {:ok, source_stream} = Otis.SourceStream.Array.from_list(ss)
    {:ok, audio_stream} = Otis.AudioStream.start_link(source_stream, 200)
    {:ok, audio_stream: audio_stream, chunk_size: 200}
  end

  defp test_frame_size(stream, size) do
    test_frame_size(stream, size, Otis.AudioStream.frame(stream))
  end

  defp test_frame_size(stream, size, {:ok, data}) do
    test_frame_size(stream, size, Otis.AudioStream.frame(stream), byte_size(data))
  end

  defp test_frame_size(stream, size, {:ok, data}, chunk_size) do
    assert chunk_size == size
    test_frame_size(stream, size, Otis.AudioStream.frame(stream), byte_size(data))
  end

  defp test_frame_size(_stream, _size, :stopped, chunk_size) do
    chunk_size
  end

  test "stream length", %{audio_stream: audio_stream} do
    data = TestUtils.acc_stream(audio_stream)
    assert byte_size(data) == 262656
  end

  test "stream validity", %{ audio_stream: audio_stream } do
    hash = TestUtils.md5 fn() -> Otis.AudioStream.frame(audio_stream) end
    # cat test/fixtures/snake-rag.mp3 | sox --type .mp3 - --type raw --bits 16 --channels 2 --endian little --rate 44100 --encoding signed-integer s1.raw
    # cat test/fixtures/silent.mp3 | sox --type .mp3 - --type raw --bits 16 --channels 2 --endian little --rate 44100 --encoding signed-integer s2.raw
    # cat s1.raw s2.raw s1.raw | md5 && rm s1.raw s2.raw
    assert hash == "5531fbf9d9dfd458aea12eb262bedb35"
  end

  test "keeps a constant frame size across sources", %{audio_stream: audio_stream, chunk_size: chunk_size} do
    remainder = test_frame_size(audio_stream, chunk_size)
    assert remainder == (262656 - chunk_size * ( round(Float.floor(262656 / chunk_size)) ))
  end
end

