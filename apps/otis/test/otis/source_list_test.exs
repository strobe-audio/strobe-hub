defmodule Otis.Source.Test do
  def new(id) do
    %{ id: id }
  end
  def id(%{id: id}), do: id
  def open!(_source, _packet_size_bytes), do: []
  def close(_file, _source), do: nil
  def audio_type(_source), do: {"mp3", "audio/mpeg"}
  def metadata(_source), do: %Otis.Source.Metadata{}
end

defmodule Otis.SourceListTest do
  use   ExUnit.Case, async: true
  alias Otis.Source.Test, as: TS

  setup do
    sources = [
      TS.new("a"),
      TS.new("b"),
      TS.new("c"),
      TS.new("d"),
    ]
    {:ok, list} = Otis.SourceList.from_list(sources)
    {:ok, sources: sources, source_list: list}
  end

  test "it gives each source a unique id", %{source_list: list} do
    {:ok, sources} = Otis.SourceList.list(list)
    ids = Enum.map sources, fn({id, _source}) -> id end
    assert length(Enum.uniq(ids)) == length(ids)
  end

  test "it gives new sources a unique id", %{source_list: list} do
    source = TS.new("e")
    {:ok, sources} = Otis.SourceList.list(list)
    l = length(sources)
    Otis.SourceList.append_source(list, source)
    {:ok, sources} = Otis.SourceList.list(list)
    ids = Enum.map sources, fn({id, _source}) -> id end
    assert length(Enum.uniq(ids)) == length(ids)
    assert length(ids) == l + 1
  end

  test "it gives new multiple sources unique ids", %{source_list: list} do
    new_sources = [TS.new("e"), TS.new("f")]
    {:ok, sources} = Otis.SourceList.list(list)
    l = length(sources)
    Otis.SourceList.append_sources(list, new_sources)
    {:ok, sources} = Otis.SourceList.list(list)
    ids = Enum.map sources, fn({id, _source}) -> id end
    assert length(Enum.uniq(ids)) == length(ids)
    assert length(ids) == l + 2
  end

  test "#next iterates the source list" do
    {:ok, a } = Otis.Source.File.new("test/fixtures/silent.mp3")
    {:ok, b } = Otis.Source.File.new("test/fixtures/snake-rag.mp3")
    {:ok, source_list} = Otis.SourceList.from_list([a, b])

    {:ok, _uuid, source} = Otis.SourceList.next(source_list)
    %Otis.Source.File{path: path} = source

    assert path == Path.expand("../fixtures/silent.mp3", __DIR__)

    {:ok, _uuid, source} = Otis.SourceList.next(source_list)
    %Otis.Source.File{path: path} = source
    assert path == Path.expand("../fixtures/snake-rag.mp3", __DIR__)

    result = Otis.SourceList.next(source_list)
    assert result == :done
  end
  test "skips a single track", state do
    {:ok, 3} = Otis.SourceList.skip(state.source_list, 1)
    {:ok, _id, source} = Otis.SourceList.next(state.source_list)
    assert source.id == "b"
  end

  test "skips multiple tracks", state do
    {:ok, 1} = Otis.SourceList.skip(state.source_list, 3)
    {:ok, _id, source} = Otis.SourceList.next(state.source_list)
    assert source.id == "d"
  end
end


