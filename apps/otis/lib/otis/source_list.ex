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
  @spec from_list(binary, [Otis.Library.Source.t]) :: {:ok, pid}
  def from_list(id, sources) do
    start_link(id, Enum.map(sources, &source_with_id/1))
  end

  @doc "GenServer api to start an instance with the given list of sources"
  @spec start_link(binary, [Otis.Library.Source.t]) :: {:ok, pid}
  def start_link(id, sources) do
    GenServer.start_link(__MODULE__, {id, sources})
  end

  @doc "Returns the next source in the list"
  @spec next(pid) :: {:ok, Otis.Library.Source.t}
  def next(source_list) do
    source = GenServer.call(source_list, :next_source)
    source
  end

  @doc "Appends the given List of Sources"
  @spec append(pid, list(Otis.Library.Source.t)) :: {:ok, integer}
  def append(list, []) do
    {:ok, count(list)}
  end
  def append(list, [source | sources]) do
    append(list, source)
    append(list, sources)
  end

  @doc "Appends the given Source to the list"
  @spec append(pid, Otis.Library.Source.t) :: :ok
  def append(list, source) do
    insert_source(list, source, -1)
  end

  @doc """
  Inserts the given source into the list at the given position (-1 to append)
  """
  @spec insert_source(pid, Otis.Library.Source.t, integer) :: :ok
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

  @doc "Gives the duration of the current list"
  def duration(list) do
    GenServer.call(list, :duration)
  end

  @doc "Silently replaces the contents of the source list"
  def replace(list, sources) do
    GenServer.call(list, {:replace, sources})
  end

  def active(list) do
    GenServer.call(list, :active)
  end

  # def move(list, id, new_position) do
    # can be implemented by
    # matches = fn({source_id, source}) -> source_id == id end
    # value = Enum.find(matches)
    # list |> Enum.reject(matches) |> List.insert_at(new_position, value)
  # end

  ###### GenServer Callbacks

  defmodule S do
    @moduledoc false
    defstruct [:id, :sources, :position, :active]
  end

  def init({id, sources}) do
    state = %S{id: id, sources: sources, position: 0}
    {:ok, state}
  end

  def handle_call(:next_source, _from, %S{sources: []} = state) do
    {:reply, :done, state}
  end
  def handle_call(:next_source, _from, %S{sources: [{id, playback_position, source} = active | sources]} = state) do
    {:reply, {:ok, id, playback_position, source}, %S{ state | sources: sources, active: active }}
  end

  def handle_call(:clear, _from, %S{sources: sources} = state) do
    Enum.each(sources, fn({id, _offset, _source}) ->
      Otis.State.Events.notify({:source_deleted, [id, state.id]})
    end)
    Otis.State.Events.notify({:source_list_cleared, [state.id]})
    {:reply, :ok, %S{ state | sources: [] }}
  end

  def handle_call(:count, _from, state) do
    {:reply, length(state.sources), state}
  end

  def handle_call({:add_source, source, index}, _from, %S{sources: sources} = state) do
    entry = source_with_id(source)
    sources = sources |> List.insert_at(index, entry)
    Otis.State.Events.notify({:new_source,
      [ state.id,
        insert_offset_to_position(sources, index, state),
        entry
      ]
    })
    {:reply, {:ok, length(sources)}, %S{ state | sources: sources }}
  end

  def handle_call({:skip, id}, _from, state) do
    {drop, keep} = skip_to(id, state)
    Otis.State.Events.notify({:sources_skipped, [state.id, Enum.map(drop, &(elem(&1, 0)))]})
    {:reply, {:ok, length(keep)}, %S{ state | sources: keep, active: nil }}
  end

  def handle_call(:list, _from, %S{sources: sources} = state) do
    {:reply, {:ok, sources}, state}
  end

  def handle_call({:replace, new_sources}, _from, state) do
    {:reply, :ok, %S{state | sources: new_sources}}
  end

  def handle_call(:active, _from, state) do
    {:reply, {:ok, state.active}, state}
  end

  def handle_call(:duration, _from, state) do
    duration = Enum.reduce(state.sources, 0, fn({_id, _offset, source}, acc) ->
      {:ok, duration} = Otis.Library.Source.duration(source)
      acc + duration
    end)
    {:reply, {:ok, duration}, state}
  end

  defp skip_to(id, %S{active: active, sources: sources} = state) do
    skip_to(id, active, sources, state)
  end
  defp skip_to(id, nil, sources, state) do
    skip_to(id, sources, state)
  end
  # Make sure that we also flag the current source as needing deletion from the db
  defp skip_to(id, active, sources, state) do
    skip_to(id, [active | sources], state)
  end
  defp skip_to(id, sources, _state) do
    sources |> Enum.split_while(fn({source_id, _, _}) -> source_id != id end)
  end

  # Converts an insertion position (e.g. -1 for end into
  # an absolute position). Note that this is called *after* insertion
  # so we can use the actual list length in our calculations.
  defp insert_offset_to_position(sources, index, %{active: nil}) do
    list_relative_offset(sources, index)
  end

  defp insert_offset_to_position(sources, index, _state) do
    list_relative_offset(sources, index) + 1
  end

  defp list_relative_offset(sources, index) do
    if index < 0 do
      length(sources) + index
    else
      index
    end
  end

  def source_with_id(source) do
    {next_source_id(source), 0, source}
  end

  # Has to be valid/unique across all source lists and across broadcaster restarts
  def next_source_id(_source) do
    Otis.uuid()
  end
end
