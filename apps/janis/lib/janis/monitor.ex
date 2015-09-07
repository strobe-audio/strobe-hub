defmodule Janis.Monitor do
  use GenServer

  @monitor_name Janis.Monitor

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: @monitor_name)
  end

  def handle_call({:sync, {originate_ts} = packet}, _from, state) do
    {:reply, {originate_ts, Janis.microseconds}, state}
  end
end
