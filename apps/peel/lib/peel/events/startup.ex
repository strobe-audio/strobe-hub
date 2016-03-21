defmodule Peel.Events.Startup do
  use     GenEvent
  require Logger

  def register do
    IO.inspect [Peel.Events.Startup]
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event(evt, state) do
    IO.inspect [:peel, evt]
    {:ok, state}
  end
end
