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

  def append_source(sources, source) do
    insert_source(sources, source, -1)
  end

  def insert_source(sources, source, position \\ -1) do
    GenServer.cast(sources, {:add_source, source, position})
  end
end
