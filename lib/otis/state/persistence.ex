defmodule Otis.State.Persistence do
  use     GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  @handlers [
    Otis.State.Persistence.Channels,
    Otis.State.Persistence.Receivers,
    Otis.State.Persistence.Renditions,
  ]

  def init(:ok) do
    Enum.each @handlers, fn(handler) ->
      handler.register
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
