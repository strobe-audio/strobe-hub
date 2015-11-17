defmodule Otis.SourceStream.Array do
  use GenServer

  def empty do
    from_list([])
  end

  def from_list(sources) do
    source = %{sources: sources, position: 0}
    start_link(source)
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
  end

  def handle_cast({:add_source, source, index}, %{sources: sources} = state) do
    {:noreply, %{ state | sources: List.insert_at(sources, index, source) }}
  end
end
