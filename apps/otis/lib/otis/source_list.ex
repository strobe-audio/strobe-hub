defmodule Otis.SourceList do
  use GenServer

  def empty do
    from_list([])
  end

  def from_list(sources) do
    source = %{sources: sources, position: 0}
    start_link(source)
  end

  @doc "Returns the next source in the list"
  def next(source_list) do
    source = GenServer.call(source_list, :next_source)
    source
  end

  @doc "Returns the current source"
  def current(source_list) do
    GenServer.call(source_list, :current_source)
  end

  def append_sources(_list, []) do
    :ok
  end

  def append_sources(list, [source | sources]) do
    append_source(list, source)
    append_sources(list, sources)
  end

  def append_source(list, source) do
    insert_source(list, source, -1)
  end

  def insert_source(list, source, position \\ -1) do
    GenServer.cast(list, {:add_source, source, position})
    :ok
  end

  def start_link(sources) do
    GenServer.start_link(__MODULE__, sources)
  end

  def handle_call(:next_source, _from, %{sources: []} = state) do
    {:reply, :done, state}
  end

  # TODO: I don't need to save a list of source processes in here
  # just a list of Source.Stream protocol implementers then
  # I can just translate that into a source instance on demand
  def handle_call(:next_source, _from, %{sources: [h | t]} = state) do
    {:reply, {:ok, h}, %{ state | sources: t }}
  def handle_call(:next_source, _from, %{sources: [source | sources]} = state) do
    {:reply, open_source(source), %{ state | sources: sources }}
  end

  def handle_cast({:add_source, source, index}, %{sources: sources} = state) do
    {:noreply, %{ state | sources: List.insert_at(sources, index, source) }}
  end

  defp open_source(source) do
    Otis.SourceStream.new(source)
  end
end
