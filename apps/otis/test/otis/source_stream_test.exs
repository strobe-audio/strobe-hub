defmodule Otis.SourceStreamTest do
  use ExUnit.Case

  test "opening silent mp3 should give a data stream of all 0" do
    {:ok, source} = Otis.Source.File.new("test/fixtures/silent.mp3")
    {:ok, _id, 0, 52, stream} = Otis.SourceStream.new(Otis.uuid, 0, source)
    {:ok, pcm } = Otis.SourceStream.chunk stream
    assert byte_size(pcm) == 4608

    Enum.each :binary.bin_to_list(pcm), fn(b) ->
      assert b == 0
    end

    {:ok, pcm} = Otis.SourceStream.chunk stream
    assert byte_size(pcm) == 4608
    Enum.each :binary.bin_to_list(pcm), fn(b) ->
      assert b == 0
    end

    result = Otis.SourceStream.chunk stream
    assert result == :done
  end

  test "opening streaming mp3 should give a valid PCM data stream" do
    {:ok, source} = Otis.Source.File.new("test/fixtures/snake-rag.mp3")
    {:ok, _id, 0, 757, stream} = Otis.SourceStream.new(Otis.uuid(), 0, source)
    hash = TestUtils.md5 fn() -> Otis.SourceStream.chunk(stream) end
    # avconv -i test/fixtures/snake-rag.mp3 -f s16le -ac 2 -ar 44100 - | md5
    assert hash == "ba5a1791d3a00ac3ec31f2fe490a90c5"
  end
end
