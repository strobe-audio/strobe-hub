defmodule Otis.AudioStreamSingleTest do
  use ExUnit.Case, async: true

  # avconv -i test/fixtures/silent.mp3 -f s16le -ac 2 -ar 44100 silent.raw
  @silent_raw_byte_size 9216

  setup do
    source_list_id = Otis.uuid
    {:ok, source} = Otis.Source.File.new("test/fixtures/silent.mp3")
    {:ok, source_list} = Otis.SourceList.from_list(source_list_id, [source])
    {:ok, audio_stream} = Otis.AudioStream.start_link(source_list, 1000)
    {:ok, audio_stream: audio_stream, chunk_size: 1000, source_list: source_list, source_list_id: source_list_id}
  end

  test "source list", %{audio_stream: audio_stream, chunk_size: chunk_size} do
    n = @silent_raw_byte_size / chunk_size
    Enum.each 0..round(Float.floor(n) - 1 ), fn(_) ->
      { :ok, packet } = Otis.AudioStream.frame(audio_stream)
      assert byte_size(packet.data) == chunk_size
    end
    {:ok, packet} = Otis.AudioStream.frame(audio_stream)
    assert byte_size(packet.data) == rem(@silent_raw_byte_size, chunk_size)
    result = Otis.AudioStream.frame(audio_stream)
    assert result == :stopped
  end

  test "adding a source after finishing the first", %{audio_stream: audio_stream, chunk_size: chunk_size, source_list: source_list} do
    n = @silent_raw_byte_size / chunk_size
    Enum.each 0..round(Float.floor(n) - 1), fn(_) ->
      { :ok, packet } = Otis.AudioStream.frame(audio_stream)
      assert byte_size(packet.data) == chunk_size
    end

    {:ok, packet} = Otis.AudioStream.frame(audio_stream)
    assert byte_size(packet.data) == rem(@silent_raw_byte_size, chunk_size)

    result = Otis.AudioStream.frame(audio_stream)
    assert result == :stopped

    {:ok, source} = Otis.Source.File.new("test/fixtures/silent.mp3")
    {:ok, 1} = Otis.SourceList.append(source_list, source)

    Enum.each 0..round(Float.ceil(n) - 2), fn(_) ->
      { :ok, packet } = Otis.AudioStream.frame(audio_stream)
      assert byte_size(packet.data) == chunk_size
    end
    {:ok, packet} = Otis.AudioStream.frame(audio_stream)
    assert byte_size(packet.data) == rem(@silent_raw_byte_size, chunk_size)
    :stopped = Otis.AudioStream.frame(audio_stream)
  end
end

defmodule Otis.AudioStreamMultipleTest do
  use ExUnit.Case, async: true

  @transcoded_stream_size 276480

  setup do
    paths = [
      "test/fixtures/snake-rag.mp3",
      "test/fixtures/silent.mp3",
      "test/fixtures/snake-rag.mp3"
    ]
    source_list_id = Otis.uuid
    ss  = Enum.map paths, fn(path) ->
      {:ok, source } = Otis.Source.File.new(path)
      source
    end
    {:ok, source_list} = Otis.SourceList.from_list(source_list_id, ss)
    {:ok, audio_stream} = Otis.AudioStream.start_link(source_list, 200)
    {:ok, audio_stream: audio_stream, chunk_size: 200, source_list_id: source_list_id}
  end

  defp test_frame_size(stream, size) do
    test_frame_size(stream, size, Otis.AudioStream.frame(stream))
  end

  defp test_frame_size(stream, size, {:ok, packet}) do
    test_frame_size(stream, size, Otis.AudioStream.frame(stream), byte_size(packet.data))
  end

  defp test_frame_size(stream, size, {:ok, packet}, chunk_size) do
    assert chunk_size == size
    test_frame_size(stream, size, Otis.AudioStream.frame(stream), byte_size(packet.data))
  end

  defp test_frame_size(_stream, _size, :stopped, chunk_size) do
    chunk_size
  end

  test "stream length", %{audio_stream: audio_stream} do
    data = TestUtils.acc_stream(audio_stream)
    assert byte_size(data) == @transcoded_stream_size
  end

  ## Now that we're padding songs to always end at the end of a chunk, this is
  ## difficult to test..
  # test "stream validity", %{ audio_stream: audio_stream } do
  #   hash = TestUtils.md5 fn() -> Otis.AudioStream.frame(audio_stream) end
  #   # cat test/fixtures/snake-rag.mp3 | avconv -f mp3 -i - -f s16le -ac 2 -ar 44100 s1.raw
  #   # cat test/fixtures/silent.mp3 | avconv -f mp3 -i - -f s16le -ac 2 -ar 44100 s2.raw
  #   # cat s1.raw s2.raw s1.raw | md5 && rm s1.raw s2.raw
  #   assert hash == "a3c1a1434637eeb0abc93cd0a24f5c17"
  # end

  test "keeps a constant frame size across sources", %{audio_stream: audio_stream, chunk_size: chunk_size} do
    remainder = test_frame_size(audio_stream, chunk_size)
    assert remainder == rem(@transcoded_stream_size, chunk_size)
  end
end

