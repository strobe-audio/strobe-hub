defmodule Strobe.Events.Producer do
  use GenStage
  require Logger
  require Strobe.Events

  def start_link do
    GenStage.start_link(__MODULE__, [], name: Strobe.Events.name())
  end

  def init(_opts) do
    Logger.info("Starting #{__MODULE__}")
    {:producer, [], dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  def handle_call({:notify, event}, _from, state) do
    {:reply, :ok, [event], state}
  end

  def handle_cast({:notify, event}, state) do
    {:noreply, [event], state}
  end
end
