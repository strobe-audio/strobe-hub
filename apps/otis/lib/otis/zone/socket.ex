defmodule Otis.Zone.Socket do
  use     GenServer
  require Logger
  alias   Otis.Receiver, as: Receiver

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, [])
  end

  def init(id) do
    Logger.debug "Starting socket with id #{id}"
    {:ok, {id, [], 0}}
  end

  def send(pid, timestamp, data) do
    GenServer.cast(pid, {:send, timestamp, data})
  end

  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  def add_receiver(pid, receiver) do
    GenServer.cast(pid, {:add_receiver, receiver})
  end

  def remove_receiver(pid, receiver) do
    GenServer.cast(pid, {:remove_receiver, receiver})
  end

  def receivers(pid) do
    GenServer.call(pid, :receivers)
  end

  def handle_call(:receivers, _from, {_, receivers, _} = state) do
    {:reply, {:ok, receivers}, state}
  end

  def handle_cast({:send, _timestamp, :stopped}, state) do
    {:noreply, state}
  end

  def handle_cast({:send, timestamp, audio}, {id, receivers, count} = _state) do
    packet = <<
      count     :: size(64)-little-unsigned-integer,
      timestamp :: size(64)-little-signed-integer,
      audio     :: binary
    >>
    _send(receivers, packet)
    {:noreply, {id, receivers, count + 1}}
  end

  def handle_cast(:stop, {id, receivers, _count} = _state) do
    _send(receivers, <<"STOP">>)
    {:noreply, {id, receivers, 0}}
  end

  def handle_cast({:add_receiver, receiver}, {id, receivers, count}) do
    Receiver.monitor(receiver)
    {:noreply, {id, [receiver | receivers], count}}
  end

  def handle_cast({:remove_receiver, receiver}, state) do
    state = state |> _remove_receiver(receiver)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state = state |> _remove_receiver(pid)
    {:noreply, state}
  end

  defp _remove_receiver(state, nil) do
    state
  end
  defp _remove_receiver({_, receivers, _} = state, pid) when is_pid(pid) do
    _remove_receiver(state, Receiver.matching_pid(receivers, pid))
  end
  defp _remove_receiver({id, receivers, count}, receiver) do
    receivers = receivers |> Enum.reject(&Receiver.equal?(&1, receiver))
    {id, receivers, count}
  end

  defp _send([], _data) do
    nil
  end
  defp _send([receiver | receivers], data) do
    Receiver.send_data(receiver, data)
    _send(receivers, data)
  end
end
