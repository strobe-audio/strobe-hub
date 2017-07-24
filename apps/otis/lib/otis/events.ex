defmodule Otis.Events do
  use GenStage
  require Logger

  @name __MODULE__

  def start_link do
    GenStage.start_link(__MODULE__, [], name: @name)
  end

  @doc """
  Find the event producer process for subscription along with a selector
  function for event filtering.
  """
  @spec producer((term -> boolean)) :: [pid] | [{pid, keyword}]
  def producer(selector) do
    case producer() do
      [] -> []
      [pid] -> [{pid, selector: selector}]
    end
  end

  @doc """
  Find the event producer process for subscription. If the events service is
  not running returns `[]`.
  """
  @spec producer :: [pid]
  def producer do
    @name |> GenServer.whereis |> List.wrap
  end

  @doc """
  Send an event to all registered handlers asynchronously.
  """
  @spec notify(atom, atom, list) :: :ok
  def notify(category, event, args \\ [])
  def notify(category, event, args)
  when is_atom(category) and is_atom(event) and is_list(args) do
    GenStage.cast(@name, {:notify, {category, event, args}})
  end

  @doc """
  A macro that emits special completion events when in `:test` environment.

  This along with `use Otis.Events.Handler` provides a mechanism for waiting
  until the effects of an event have been persisted to the db before continuing
  with test assertions.
  """
  defmacro complete(event) do
    if Mix.env == :test do
      quote do
        GenStage.cast(unquote(@name), {:notify, {:__complete__, unquote(event), __MODULE__}})
      end
    end
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
