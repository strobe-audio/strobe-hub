defmodule Strobe.Server.Events do
  use GenStage
  require Logger

  @name __MODULE__

  def start_link do
    GenStage.start_link(__MODULE__, [], name: @name)
  end

  def producer do
    @name |> GenServer.whereis() |> List.wrap()
  end

  def notify({name, args} = event) when is_atom(name) and is_list(args) do
    GenStage.cast(@name, {:notify, event})
  end

  def init(_opts) do
    {:producer, [], dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  def handle_call({:notify, event}, _from, state) do
    Logger.debug("EVENT #{__MODULE__}")
    {:reply, :ok, [event], state}
  end

  def handle_cast({:notify, event}, state) do
    Logger.debug("EVENT #{__MODULE__}")
    {:noreply, [event], state}
  end
end
