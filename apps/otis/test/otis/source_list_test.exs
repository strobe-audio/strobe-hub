defmodule Otis.Source.Test do
  def new(id) do
    %{ id: id }
  end
  def id(%{id: id}), do: id
  def open!(source, packet_size_bytes), do: []
  def close(file, source)
  def audio_type(source), do: {"mp3", "audio/mpeg"}
  def metadata(source), do: %Otis.Source.Metadata{}
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

  test "skips a single track", state do
    {:ok, 3} = Otis.SourceList.skip(state.source_list, 1)
    {:ok, source} = Otis.SourceList.next(state.source_list)
    assert source.id == "b"
  end

  test "skips multiple tracks", state do
    {:ok, 1} = Otis.SourceList.skip(state.source_list, 3)
    {:ok, source} = Otis.SourceList.next(state.source_list)
    assert source.id == "d"
  end
end
