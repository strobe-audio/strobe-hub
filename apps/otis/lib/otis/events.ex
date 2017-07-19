defmodule Otis.Events do
  use GenStage
  require Logger

  @name __MODULE__

  def start_link do
    GenStage.start_link(__MODULE__, [], name: @name)
  end

  def producer do
    @name |> GenServer.whereis |> List.wrap
  end

  def notify(category, event, args \\ [])
  def notify(category, event, args)
  when is_atom(category) and is_atom(event) and is_list(args) do
    GenStage.cast(@name, {:notify, {category, event, args}})
  end

  def sync_notify(category, event, args \\ [])
  def sync_notify(category, event, args)
  when is_atom(category) and is_atom(event) and is_list(args) do
    GenStage.call(@name, {:notify, {category, event, args}})
  end

  defmacro complete(event) do
    if Mix.env == :test do
      quote do
        Otis.Events.notify_complete(unquote(event), __MODULE__)
      end
    end
  end

  def notify_complete(event, module) do
    GenStage.cast(@name, {:notify, {:__complete__, event, module}})
  end

  def init(_opts) do
    Logger.info "Starting #{__MODULE__}"
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
