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

  def handle_call(:next_source, _from, %{sources: [h | t]} = state) do
    {:reply, {:ok, h}, %{ state | sources: t }}
  end

  def handle_cast({:add_source, source, index}, %{sources: sources} = state) do
    {:noreply, %{ state | sources: List.insert_at(sources, index, source) }}
  end

  def handle_cast(:pre_buffer, %{sources: []} = state) do
    {:noreply, state}
  end

  def handle_cast(:pre_buffer, %{sources: [source | t]} = state) do
    GenServer.cast(source, :pre_buffer)
    {:noreply, state}
  end
end
