defmodule Otis.State.Persistence do
  use     GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    Otis.State.Persistence.Zones.register
    {:ok, {}}
  end

  def handle_info({:gen_event_EXIT, handler, reason}, state) do
    Logger.warn "Restarting persistence handler #{ inspect handler }"
    handler.register
    {:noreply, state}
  end
end
