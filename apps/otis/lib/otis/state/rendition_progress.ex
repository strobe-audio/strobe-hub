defmodule Otis.State.RenditionProgress do
  use GenServer

  alias Otis.State.Repo
  alias Otis.State.Repo.Writer

  require Logger

  @name __MODULE__

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def update(rendition_id, progress) do
    GenServer.call(@name, {:progress, rendition_id, progress})
  end

  def save do
    GenServer.call(@name, :save)
  end

  def init(_opts) do
    schedule()
    Process.flag(:trap_exit, true)
    {:ok, %{}}
  end

  def handle_call({:progress, rendition_id, progress}, _from, state) do
    {:reply, :ok, Map.put(state, rendition_id, progress)}
  end

  def handle_call(:save, _from, state) do
    save(state)
    {:reply, :ok, %{}}
  end

  def handle_info(:flush, state) when state == %{} do
    schedule()
    {:noreply, %{}}
  end

  def handle_info(:flush, state) do
    save(state)
    schedule()
    {:noreply, %{}}
  end

  def terminate(_reason, state) do
    save(state)
    :ok
  end

  defp schedule do
    Process.send_after(self(), :flush, 1_000)
  end

  defp save(state) do
    Writer.transaction(fn ->
      Enum.each(state, &save_progress/1)
    end)
  end

  @update_query "UPDATE OR IGNORE renditions SET playback_position = $1 WHERE id = $2"

  defp save_progress({rendition_id, position}) do
    {:ok, id} = Ecto.UUID.dump(rendition_id)
    Ecto.Adapters.SQL.query!(Repo, @update_query, [position, id])
  end
end
