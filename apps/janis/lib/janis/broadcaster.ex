defmodule Janis.Broadcaster do
  use GenServer
  require Logger

  @name  Janis.Broadcaster

  def start_link(node_name) do
    GenServer.start_link(__MODULE__, node_name, name: @name)
  end

  def init(node_name) do
    Logger.debug "Starting broadcaster  #{node_name}"
    {:ok, monitor} = Janis.Monitor.start_link(self)
    {:ok, %{broadcaster: node_name, monitor: monitor}}
  end

  def handle_cast({:receiver_latency, latency}, %{broadcaster: broadcaster} = state) do
    Logger.debug "Broadcaster new latency #{latency} #{inspect broadcaster}"
    IO.inspect GenServer.cast({Otis.Receivers, broadcaster}, {:receiver_latency, node, latency})
    {:noreply, state}
  end

  def handle_call(:measure_latency, _from, %{broadcaster: broadcaster} = state) do
    start = Janis.microseconds
    response = GenServer.call({Otis.Receivers, broadcaster}, {:time_sync, {start}})
    {:ok, {_start, receipt}} = response
    finish = Janis.microseconds
    {:reply, {:ok, {start, receipt, finish}}, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
