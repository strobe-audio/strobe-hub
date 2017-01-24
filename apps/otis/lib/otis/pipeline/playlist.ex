defmodule Otis.Pipeline.Playlist do
  use GenServer
  @moduledoc """
  A list of renditions
  """

  alias Otis.State.Rendition
  alias Otis.State.Events

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
  def duration(pid) do
    GenServer.call(pid, :duration)
  end
  def replace(pid, renditions) do
    GenServer.cast(pid, {:replace, renditions})
  end
  def remove(pid, id) when is_binary(id) do
    GenServer.cast(pid, {:remove, id})
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
    {:reply, {:ok, all_renditions(state)}, state}
  end
  def handle_call(:next, _from, %S{renditions: []} = state) do
    {:reply, :done, %S{ state | active: nil }}
  end
  def handle_call(:next, _from, %S{renditions: [a | renditions]} = state) do
    {:reply, {:ok, a}, %S{ state | renditions: renditions, active: a }}
  end
  def handle_call(:duration, _from, state) do
    duration = Enum.reduce(state.renditions, 0, fn(r, d) ->
      d + Rendition.duration(r)
    end)
    {:reply, {:ok, duration}, state}
  end
  def handle_call(:clear, _from, state) do
    notify_deletions(state.renditions, state)
    Events.notify({:playlist_cleared, [state.id]})
    {:reply, :ok, %S{ state | renditions: [] }}
  end

  def handle_cast({:append, sources}, state) do
    renditions = make_renditions(List.wrap(sources), state)
    Events.notify({:new_renditions, [state.id, renditions]})
    {:noreply, %S{ state | renditions: Enum.concat(state.renditions, renditions) }}
  end
  def handle_cast({:replace, renditions}, state) do
    {:noreply, %S{ state | renditions: renditions, active: nil }}
  end
  def handle_cast({:skip, id}, state) do
    renditions = all_renditions(state)
    {drop, keep} = Enum.split_while(renditions, fn(r) -> r.id != id end)
    notify_skip(drop, state)
    notify_deletions(drop, state)
    {:noreply, %S{ state | renditions: keep, active: nil }}
  end
  def handle_cast({:remove, id}, state) do
    {drop, keep} = state.renditions |> Enum.split_with(fn(r) -> r.id == id end)
    notify_deletions(drop, state)
    active = case state.active do
      %Rendition{id: ^id} = a ->
        notify_deletions([a], state)
        nil
      nil -> nil
      a -> a
    end
    {:noreply, %S{ state | renditions: keep, active: active }}
  end

  defp notify_deletions(renditions, state) do
    Enum.each(renditions, fn(r) ->
      Events.notify({:rendition_deleted, [r.id, state.id]})
    end)
  end
  defp notify_skip(renditions, state) do
    ids = Enum.map(renditions, fn(r) -> r.id end)
    Events.notify({:renditions_skipped, [state.id, ids]})
  end

  defp all_renditions(state) do
    [state.active | state.renditions] |> Enum.reject(&is_nil/1)
  end

  defp make_renditions(sources, state) do
    make_renditions(sources, length(all_renditions(state)), [], state.id)
  end

  defp make_renditions([], _n, renditions, _id) do
    Enum.reverse(renditions)
  end
  defp make_renditions([s | rest], n, renditions, id) do
    r = make_rendition(s, n, id)
    make_renditions(rest, n + 1, [r | renditions], id)
  end

  def make_rendition(source, n, channel_id) do
    id = next_rendition_id()
    source_id = Otis.Library.Source.id(source)
    source_type = source |> Otis.Library.Source.type() |> to_string
    {:ok, duration} = source |> Otis.Library.Source.duration()
    %Rendition{
      id: id,
      position: n,
      playback_position: 0,
      playback_duration: duration,
      channel_id: channel_id,
      source_id: source_id,
      source_type: source_type,
    } |> Rendition.sanitize_playback_duration()
  end
  def next_rendition_id() do
    Otis.uuid()
  end
end

