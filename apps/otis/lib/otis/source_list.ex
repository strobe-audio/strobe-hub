defmodule Otis.SourceList do
  use    GenServer

  @moduledoc """
  Provides a list of Sources and a `next` function to iterate them.
  """


  @doc "Start a new empty list instance"
  @spec empty(binary) :: {:ok, pid}
  def empty(id) do
    from_list(id, [])
  end

  @doc "Start a new list instance from the given list of sources"
  @spec from_list(binary, [Otis.Source.t]) :: {:ok, pid}
  def from_list(id, sources) do
    start_link(id, Enum.map(sources, &source_with_id/1))
  end

  @doc "GenServer api to start an instance with the given list of sources"
  @spec start_link(binary, [Otis.Source.t]) :: {:ok, pid}
  def start_link(id, sources) do
    GenServer.start_link(__MODULE__, {id, sources})
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

  @doc "Skips to the given source id"
  def skip(list, id) do
    GenServer.call(list, {:skip, id})
  end

  @doc "Lists the current sources"
  def list(list) do
    GenServer.call(list, :list)
  end

  @doc "Silently replaces the contents of the source list"
  def replace(list, sources) do
    GenServer.call(list, {:replace, sources})
  end

  # def move(list, id, new_position) do
    # can be implemented by
    # matches = fn({source_id, source}) -> source_id == id end
    # value = Enum.find(matches)
    # list |> Enum.reject(matches) |> List.insert_at(new_position, value)
  # end

  ###### GenServer Callbacks

  def init({id, sources}) do
    state = %{id: id, sources: sources, position: 0}
    {:ok, state}
  end

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
    entry = source_with_id(source)
    sources = sources |> List.insert_at(index, entry)
    Otis.State.Events.notify({
      :new_source,
      state.id,
      insert_offset_to_position(sources, index),
      entry
    })
    {:reply, {:ok, length(sources)}, %{ state | sources: sources }}
  end

  # TODO: replace count with the source's list id
  def handle_call({:skip, id}, _from, %{sources: sources} = state) do
    {drop, keep} = sources |> Enum.split_while(fn({source_id, _}) -> source_id != id end)
    Otis.State.Events.notify({:sources_skipped, state.id, Enum.map(drop, &(elem(&1, 0)))})
    {:reply, {:ok, length(keep)}, %{ state | sources: keep }}
  end

  def handle_call(:list, _from, %{sources: sources} = state) do
    {:reply, {:ok, sources}, state}
  end
  def handle_call({:replace, new_sources}, _from, state) do
    {:reply, :ok, %{state | sources: new_sources}}
  end

  # Converts an insertion position (e.g. -1 for end into
  # an absolute position). Note that this is called *after* insertion
  # so we can use the actual list length in our calculations.
  defp insert_offset_to_position(sources, index) do
    if index < 0 do
      length(sources) + index
    else
      index
    end
  end

  def source_with_id(source) do
    {next_source_id(source), source}
  end

  # Has to be valid/unique across all source lists and across broadcaster restarts
  def next_source_id(_source) do
    Otis.uuid()
  end
end
