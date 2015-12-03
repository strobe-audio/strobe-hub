defmodule Otis.SourceList do
  use GenServer

  @type t :: __MODULE__

  def empty do
    from_list([])
  end

  def from_list(sources) do
    source = %{sources: sources, position: 0}
    start_link(source)
  end

  @doc "Returns the next source in the list"
  @spec next(pid) :: {:ok, Otis.Source.t}

  def next(source_list) do
    source = GenServer.call(source_list, :next_source)
    source
  end

  @spec append_sources(pid, list(Otis.Source.t)) :: :ok

  def append_sources(_list, []) do
    :ok
  end
  def append_sources(list, [source | sources]) do
    append_source(list, source)
    append_sources(list, sources)
  end

  @spec append_source(pid, Otis.Source.t) :: :ok

  def append_source(list, source) do
    insert_source(list, source, -1)
  end

  @spec insert_source(pid, Otis.Source.t, integer) :: :ok

  def insert_source(list, source, position \\ -1) do
    GenServer.call(list, {:add_source, source, position})
  end

  def start_link(sources) do
    GenServer.start_link(__MODULE__, sources)
  end

  def handle_call(:next_source, _from, %{sources: []} = state) do
    {:reply, :done, state}
  end
  def handle_call(:next_source, _from, %{sources: [source | sources]} = state) do
    {:reply, open_source(source), %{ state | sources: sources }}
  end

  def handle_call({:add_source, source, index}, _from, %{sources: sources} = state) do
    {:reply, {:ok, Kernel.length(sources) + 1}, %{ state | sources: List.insert_at(sources, index, source) }}
  end

  defp open_source(source) do
    Otis.SourceStream.new(source)
  end
end
