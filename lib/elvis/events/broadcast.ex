defmodule Elvis.Events.Broadcast do
  use     GenEvent
  require Logger

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:receiver_added, _, _} = event, state) do
    broadcast!(event)
    {:ok, state}
  end
  def handle_event({:receiver_removed, _, _} = event, state) do
    broadcast!(event)
    {:ok, state}
  end
  def handle_event({:receiver_volume_change, _, _} = event, state) do
    broadcast!(event)
    {:ok, state}
  end
  def handle_event(event, state) do
    IO.inspect [:broadcast?, event]
    {:ok, state}
  end

  defp broadcast!(event) do
    [name | args] = Tuple.to_list(event)
    msg = %{name: name, args: args}
    Elvis.Endpoint.broadcast!("controllers:browser", "event", msg)
  end
end
