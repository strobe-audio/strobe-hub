defmodule Otis.SourceList do
  use    GenServer

  @moduledoc """
  Provides a list of Sources and a `next` function to iterate them.
  """


  @doc "Start a new empty list instance"
  @spec empty() :: {:ok, pid}
  def empty do
    from_list([])
  end

  @doc "Start a new list instance from the given list of sources"
  @spec from_list([Otis.Source.t]) :: {:ok, pid}
  def from_list(sources) do
    source = %{sources: sources, position: 0}
    start_link(source)
  end

  @doc "GenServer api to start an instance with the given list of sources"
  @spec start_link([Otis.Source.t]) :: {:ok, pid}
  def start_link(sources) do
    GenServer.start_link(__MODULE__, sources)
  end

  @doc "Returns the next source in the list"
  @spec next(pid) :: {:ok, Otis.Source.t}
  def next(source_list) do
    source = GenServer.call(source_list, :next_source)
    source
  end

  @doc "Appends the given List of Sources"
  @spec append_sources(pid, list(Otis.Source.t)) :: {:ok, integer}
  def append_sources(list, []) do
    {:ok, count(list)}
  end
  def append_sources(list, [source | sources]) do
    append_source(list, source)
    append_sources(list, sources)
  end

  @doc "Appends the given Source to the list"
  @spec append_source(pid, Otis.Source.t) :: :ok
  def append_source(list, source) do
    insert_source(list, source, -1)
  end

  @doc """
  Inserts the given source into the list at the given position (-1 to append)
  """
  @spec insert_source(pid, Otis.Source.t, integer) :: :ok
  def insert_source(list, source, position \\ -1) do
    GenServer.call(list, {:add_source, source, position})
  end

  @doc "Removes all sources from the list"
  @spec clear(pid) :: :ok
  def clear(list) do
    GenServer.call(list, :clear)
  end

  @doc "Gives the number of sources in the list"
  @spec count(pid) :: integer
  def count(list) do
    GenServer.call(list, :count)
  end

  @doc "Skips the given number of tracks"
  def skip(list, count) do
    GenServer.call(list, {:skip, count})
  end

  ###### GenServer Callbacks

  def handle_call(:next_source, _from, %{sources: []} = state) do
    {:reply, :done, state}
  end
  def handle_call(:next_source, _from, %{sources: [{id, source} | sources]} = state) do
    {:reply, {:ok, id, source}, %{ state | sources: sources }}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{ state | sources: [] }}
  end

  def handle_call(:count, _from, state) do
    {:reply, length(state.sources), state}
  end

  def handle_call({:add_source, source, index}, _from, %{sources: sources} = state) do
    sources = sources |> List.insert_at(index, source_with_id(source))
    {:reply, {:ok, length(sources)}, %{ state | sources: sources }}
  end

  # TODO: replace count with the source's list id
  def handle_call({:skip, count}, _from, %{sources: sources} = state) do
    sources = sources |> Enum.drop(count)
    {:reply, {:ok, length(sources)}, %{ state | sources: sources }}
  end

  def source_with_id(source) do
    {next_source_id, source}
  end

  # Has to be valid/unique across all source lists and across broadcaster restarts
  def next_source_id do
    UUID.uuid1()
  end
end
