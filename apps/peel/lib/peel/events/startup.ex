defmodule Peel.Events.Startup do
  use     GenEvent
  require Logger

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:controller_join, socket}, state) do
    Otis.State.Events.notify({:add_library, %{name: "Peel"}, socket})
    {:ok, state}
  end
  def handle_event(_event, state) do
    {:ok, state}
  end
end
