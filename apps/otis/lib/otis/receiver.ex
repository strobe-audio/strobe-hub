defmodule Otis.Receiver do
  use GenServer
  require Logger

  defmodule S do
    defstruct id: :receiver, node: nil, name: "Receiver", time_delta: nil, latency: nil
  end

  def start_link(id, node) do
    GenServer.start_link(__MODULE__, %S{id: id, node: node}, name: id)
  end

  def init(%S{id: id, node: node} = state) do
    Otis.Receiver.Monitor.start_link(id, node)
    {:ok, state}
  end
  #
  # def init(%S{node: node} = receiver) do
  #   IO.inspect [:init, node, self]
  #   Process.flag(:trap_exit, true)
  #   Process.link(node)
  #   {:ok, receiver}
  # end

  def id(pid) do
    GenServer.call(pid, :id)
  end

  def latency(pid) do
    GenServer.call(pid, :get_latency)
  end

  def receive_frame(pid, data, timestamp) do
    GenServer.cast(pid, {:receive_frame, data, timestamp})
  end

  def restore_state(pid, id) do
    Otis.State.restore_receiver(pid, id)
  end

  def handle_call(:id, _from, %S{id: id} = receiver) do
    {:reply, {:ok, id}, receiver}
  end

  def handle_call(:get_latency, _from, %S{latency: latency} = receiver) do
    {:reply, {:ok, latency}, receiver}
  end

  def handle_cast({:receive_frame, data, timestamp}, %S{node: node} = rec) do
    timestamp = receiver_timestamp(rec, timestamp)
    deadline = timestamp + Otis.stream_interval_us
    GenServer.cast({Janis.Player, node}, {:play, data, timestamp, deadline})
    {:noreply, rec}
  end

  def handle_cast({:update_synchronisation, latency, delta} = _sync, %S{id: id, time_delta: nil, latency: nil} = state) do
    Logger.info "New player ready #{id}: time_delta: #{delta}; latency: #{latency}"
    Otis.Receiver.restore_state(self, id)
    {:noreply, %S{ state | time_delta: delta, latency: latency }}
  end

  def handle_cast({:update_synchronisation, latency, delta}, %S{id: _id} = state) do
    # Logger.debug "New player sychronisation #{id}: latency: #{latency}; delta: #{delta}"
    {:noreply, %S{ state | time_delta: delta, latency: latency }}
  end


  def receiver_timestamp(%S{time_delta: time_delta} = _rec, player_timestamp) do
    player_timestamp + time_delta
  end

  # def terminate(reason, receiver) do
  #   IO.inspect [:receiver_terminate, reason]
  #   # Otis.Receivers.remove(Otis.Receivers, self)
  #   :ok
  # end
end
