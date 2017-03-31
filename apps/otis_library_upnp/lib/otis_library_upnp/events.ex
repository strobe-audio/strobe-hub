defmodule Otis.Library.UPNP.Events do
  use     GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  @handlers [
    Otis.Library.UPNP.Events.Library,
  ]

  def init(:ok) do
    Enum.each @handlers, fn(module) ->
       :ok = module.event_handler() |> register_handler()
    end
    {:ok, {}}
  end

  if Code.ensure_loaded?(Otis.State.Events) do
    def register_handler({handler, state}) do
      try do
        Otis.State.Events.add_mon_handler(handler, state)
      catch
        :exit, _ ->
          Logger.warn("Unable to register #{handler} event handler with Otis.State.Events")
          :ok
      end
    end
  else
    def register_handler(_) do
      :ok
    end
  end

  def handle_info({:gen_event_EXIT, handler, reason}, state) do
    Logger.warn "UPnP handler #{ inspect handler } exited with reason #{ inspect reason }"
    Logger.warn "Restarting #{ inspect handler }"
    :ok = handler.event_handler() |> register_handler()
    {:noreply, state}
  end
end


