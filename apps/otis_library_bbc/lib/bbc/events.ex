defmodule BBC.Events do
  use     GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  @handlers [
    BBC.Events.Library,
  ]

  def init(:ok) do
    Enum.each @handlers, fn(handler) ->
      :ok = handler.register
    end
    {:ok, {}}
  end

  def handle_info({:gen_event_EXIT, handler, reason}, state) do
    Logger.warn "Persistence handler #{ inspect handler } exited with reason #{ inspect reason }"
    Logger.warn "Restarting #{ inspect handler }"
    handler.register
    {:noreply, state}
  end
end
