defmodule Otis.Pipeline.Playlist do
  use GenServer
  @moduledoc """
  A list of renditions
  """

  alias Otis.State.Rendition
  alias Strobe.Events

  def next(pid) do
    GenServer.call(pid, :next)
  end

  def list(pid) do
    GenServer.call(pid, :list)
  end

  def append(pid, sources) do
    GenServer.cast(pid, {:append, sources})
  end

  def clear(pid) do
    GenServer.call(pid, :clear)
  end

  def skip(pid, id) do
    GenServer.cast(pid, {:skip, id})
  end

  def replace(pid, renditions) do
    GenServer.cast(pid, {:replace, renditions})
  end

  def remove(pid, id) when is_binary(id) do
    GenServer.cast(pid, {:remove, id})
  end

  def active_rendition(pid) do
    GenServer.call(pid, :active_rendition)
  end

  defmodule S do
    @moduledoc false
    defstruct [:id, :renditions, :position, :active]
  end

  def start_link(id) do
    GenServer.start_link(__MODULE__, [id])
  end

  def init([id]) do
    state = %S{
      id: id,
      renditions: [],
    }
    {:ok, state}
  end


  def handle_call(:list, _from, state) do
    renditions = state |> all_renditions()
    {:reply, {:ok, renditions}, state}
  end

  def handle_call(:next, _from, %S{renditions: []} = state) do
    # deactivate
    {:reply, :done, %S{state | active: nil}}
  end

  def handle_call(:next, _from, %S{renditions: [a | renditions]} = state) do
    # activate
    Events.notify(:rendition, :active, [state.id, a])
    {:reply, {:ok, a}, %S{state | renditions: renditions, active: a}}
  end

  def handle_call(:clear, _from, %S{active: active} = state) do
    # deactivate
    deactivate_renditions(state.renditions, state)
    Events.notify(:playlist, :clear, [state.id, active])
    {:reply, :ok, %S{state | renditions: []}}
  end

  def handle_call(:active_rendition, _from, %S{active: active} = state) do
    {:reply, {:ok, active}, state}
  end

  def handle_cast({:append, sources}, state) do
    renditions = sources |> List.wrap() |> make_renditions()
    activate_renditions(renditions, state)
    Events.notify(:playlist, :append, [state.id, renditions])
    # activate
    {:noreply, %S{state | renditions: Enum.concat(state.renditions, ids(renditions))}}
  end

  def handle_cast({:replace, renditions}, state) do
    # activate
    activate_renditions(renditions, state)
    {:noreply, %S{state | renditions: ids(renditions), active: nil}}
  end

  def handle_cast({:skip, :next}, state) do
    keep =
      case all_renditions(state) do
        [drop | [first | _] = renditions] ->
          # activate
          notify_skip(first, [drop], state)
          renditions
        [drop] ->
          # deactivate
          notify_skip(nil, [drop], state)
          []
        [] -> []
      end
    {:noreply, %S{state | renditions: keep, active: nil}}
  end

  def handle_cast({:skip, skip_to_id}, state) do
    renditions = all_renditions(state)
    {drop, keep} = Enum.split_while(renditions, fn(id) -> id != skip_to_id end)
    # deactivate (drop)
    notify_skip(skip_to_id, drop, state)
    {:noreply, %S{state | renditions: keep, active: nil}}
  end

  def handle_cast({:remove, remove_id}, state) do
    {drop, keep} = state.renditions |> Enum.split_with(fn(id) -> id == remove_id end)
    # deactivate (drop)
    notify_remove(drop, state)
    active = case state.active do
      ^remove_id ->
        notify_remove([remove_id], state)
        nil
      nil -> nil
      a -> a
    end
    {:noreply, %S{state | renditions: keep, active: active}}
  end

  defp ids(renditions) when is_list(renditions) do
    Enum.map(renditions, &id/1)
  end

  defp id(%Rendition{id: id}) do
    id
  end

  defp id(id) do
    id
  end

  defp notify_remove(renditions, state) do
    deactivate_renditions(renditions, state)
    Enum.each(renditions, fn(id) ->
      Events.notify(:playlist, :remove, [id, state.id])
    end)
  end

  defp notify_skip(id, renditions, state) do
    deactivate_renditions(renditions, state)
    Events.notify(:playlist, :skip, [state.id, id, renditions])
  end

  defp all_renditions(state) do
    [state.active | state.renditions] |> Enum.reject(&is_nil/1)
  end

  defp make_renditions(sources) do
    Enum.map(sources, &Rendition.from_source/1)
  end

  defp activate_renditions(renditions, state) do
    renditions
    |> List.wrap()
    |> Enum.each(&activate_rendition(&1, state.id))
  end

  defp activate_rendition(rendition, channel_id) do
    rendition
    |> Otis.State.Rendition.source()
    |> Otis.Library.Source.activate(channel_id)
  end

  defp deactivate_renditions(renditions, state) do
    renditions
    |> List.wrap()
    |> Stream.map(&Otis.State.Rendition.find/1)
    |> Enum.each(&deactivate_rendition(&1, state.id))
  end

  defp deactivate_rendition(rendition, channel_id) do
    rendition
    |> Otis.State.Rendition.source()
    |> Otis.Library.Source.deactivate(channel_id)
  end
end
