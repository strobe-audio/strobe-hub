defmodule Test.Otis.Pipeline.Transcoder do
  use ExUnit.Case

  alias Otis.Library.Source
  alias Otis.Pipeline.Transcoder
  alias Otis.Pipeline.Producer

  @dir Path.expand("../../fixtures", __DIR__)

  def test_file(filename), do: Path.join(@dir, filename)

  test "transcoding (silent)" do
    id = Otis.uuid()
    source = Otis.Source.File.new!(test_file("silent.mp3"))
    stream = Source.open!(source, id, 64)
    config = Otis.Pipeline.Config.new(20)
    {:ok, transcoder} = Transcoder.start_link(source, stream, 0, config)
    stream = Producer.stream(transcoder)# Stream.resource(start, next, stop)
    hash = :crypto.hash_init(:md5)
    {data, hash} = Enum.reduce(stream, {<<>>, hash}, fn(data, {acc, md5}) ->
      md5 = :crypto.hash_update(md5, data)
      {acc <> data, md5}
    end)

    assert byte_size(data) == 9216
    md5 = :crypto.hash_final(hash) |> Base.encode16(case: :lower)
    assert md5 == "13a95890b5f0947d6f058ca9c30a3e01"
  end

  test "transcoding (snake-rag)" do
    id = Otis.uuid()
    source = Otis.Source.File.new!(test_file("snake-rag.mp3"))
    stream = Source.open!(source, id, 64)
    config = Otis.Pipeline.Config.new(20)
    {:ok, transcoder} = Transcoder.start_link(source, stream, 0, config)
    stream = Producer.stream(transcoder)# Stream.resource(start, next, stop)
    hash = :crypto.hash_init(:md5)
    {data, hash} = Enum.reduce(stream, {<<>>, hash}, fn(data, {acc, md5}) ->
      md5 = :crypto.hash_update(md5, data)
      {acc <> data, md5}
    end)

    assert byte_size(data) == 133632
    md5 = :crypto.hash_final(hash) |> Base.encode16(case: :lower)
    assert md5 == "78e5aab4079be68850808d4bfe9f1101"
  end
end
