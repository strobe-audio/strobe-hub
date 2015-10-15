defmodule Otis.SourceStream do
  @moduledoc """
  Things that implement this protocol should just implement Enumerable.
  This would be the place to implement playlist functionality.
  SourceLists just call Enum.take/2 on this to get the next source
  """

  @doc "Returns the next source in the stream"
  def next(source_stream) do
    GenServer.call(source_stream, :next_source)
  end

  @doc "Returns the current source"
  def current(source_stream) do
    GenServer.call(source_stream, :current_source)
  end

  def append_sources(stream, []) do
  end

  def append_sources(stream, [source | sources]) do
    append_source(stream, source)
    append_sources(stream, sources)
  end

  def append_source(stream, source) do
    insert_source(stream, source, -1)
  end

  def insert_source(stream, source, position \\ -1) do
    GenServer.cast(stream, {:add_source, source, position})
  end
end
