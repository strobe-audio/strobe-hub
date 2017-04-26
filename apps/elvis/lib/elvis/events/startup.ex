defmodule Elvis.Events.Startup do
  use     GenStage
  require Logger

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: Otis.Library.Events.producer}
  end

  def handle_events([], _from,state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:controller_join, [socket]}, state) do
    # TODO: push otis current state to the browser
    Phoenix.Channel.push(socket, "state", Otis.State.current())
    {:ok, state}
  end

  def handle_event({:add_library, [library, socket]}, state) do
    Phoenix.Channel.push(socket, "add_library", library)
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end
end
