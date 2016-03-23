defmodule Elvis.Events.Startup do
  use     GenEvent
  require Logger

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:controller_join, socket}, state) do
    # TODO: push otis current state to the browser
    Phoenix.Channel.push(socket, "state", Otis.State.current())
    {:ok, state}
  end

  def handle_event({:add_library, library, socket}, state) do
    Phoenix.Channel.push(socket, "add_library", library)
    {:ok, state}
  end

  def handle_event(evt, state) do
    {:ok, state}
  end
end
