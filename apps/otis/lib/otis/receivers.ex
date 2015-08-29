defmodule Otis.Receivers do
  use GenServer

  alias Otis.Receiver

  @registry_name Otis.Receivers

  def start_link(name \\ @registry_name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def start_receiver(id, node) do
    start_receiver(@registry_name, id, node)
  end

  def start_receiver(receivers, id, node) do
    {:ok, receiver} = response = Otis.Receivers.Supervisor.start_receiver(Otis.Receivers.Supervisor, id, node)
    add(receivers, receiver)
    response
  end

  def add(receiver) do
    add(@registry_name, receiver)
  end

  def add(pid, receiver) do
    GenServer.cast(pid, {:add, receiver})
  end

  def remove(receiver) do
    remove(@registry_name, receiver)
  end

  def remove(pid, receiver) do
    GenServer.cast(pid, {:remove, receiver})
  end

  def list do
    list(@registry_name)
  end

  def list(pid) do
    GenServer.call(pid, :list)
  end

  def find(id) do
    find(@registry_name, id)
  end

  def find(pid, id) when is_atom(id) do
    GenServer.call(pid, {:find, Atom.to_string(id)})
  end

  def find(pid, id) do
    GenServer.call(pid, {:find, id})
  end

  ############# Callbacks

  def handle_call(:list, _from, receivers) do
    zones = Enum.map receivers, fn({_id, zone}) -> zone end
    {:reply, {:ok, zones}, receivers}
  end

  def handle_call({:find, id}, _from, receivers) do
    {:reply, find_by_id(receivers, id), receivers}
  end

  def handle_cast({:add, receiver}, receivers) do
    {:ok, id} = Receiver.id(receiver)
    {:noreply, [{id, receiver} | receivers]}
  end

  def handle_cast({:remove, receiver}, receivers) do
    {:ok, id} = Receiver.id(receiver)
    {:noreply, Enum.reject(receivers, fn({rid, _rec}) -> rid == id end) }
  end

  defp find_by_id(receivers, id) do
    receivers |>
    Enum.find(fn({rid, _zone}) -> Atom.to_string(rid) == id end) |>
    find_result
  end

  defp find_by_id(receivers, id) do
    receivers |>
    Enum.find(fn({rid, _zone}) -> Atom.to_string(rid) == id end) |>
    find_result
  end

  defp find_result(nil) do
    :error
  end

  defp find_result({_id, receiver}) do
    {:ok, receiver}
  end
end

