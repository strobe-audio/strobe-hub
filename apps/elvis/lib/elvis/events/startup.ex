defmodule Elvis.Events.Startup do
  use     GenStage
  require Logger

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: Strobe.Events.producer}
  end

  def handle_events([], _from,state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:controller, :join, [socket]}, state) do
    Phoenix.Channel.push(socket, "state", Otis.State.current())
    {:ok, state}
  end

  def handle_event({:library, :add, [library, socket]}, state) do
    Phoenix.Channel.push(socket, "library-add", library)
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end
end
