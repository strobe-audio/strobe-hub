defmodule Strobe.Events do
  @doc """
  Macro to enable easy sharing of a common process name.
  """
  defmacro name do
    quote do
      Strobe.Events.Producer
    end
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
    name() |> GenServer.whereis() |> List.wrap()
  end

  @doc """
  Send an event to all registered handlers asynchronously.
  """
  @spec notify(atom, atom, list) :: :ok
  def notify(category, event, args \\ [])

  def notify(category, event, args)
      when is_atom(category) and is_atom(event) and is_list(args) do
    GenStage.cast(name(), {:notify, {category, event, args}})
  end

  @doc """
  A macro that emits special completion events when in `:test` environment.

  This along with `use Strobe.Events.Handler` provides a mechanism for waiting
  until the effects of an event have been persisted to the db before continuing
  with test assertions.
  """
  defmacro complete(event) do
    if Mix.env() == :test do
      quote do
        IO.inspect(complete: {unquote(event), __MODULE__})
        GenStage.cast(unquote(name()), {:notify, {:__complete__, unquote(event), __MODULE__}})
      end
    end
  end
end
