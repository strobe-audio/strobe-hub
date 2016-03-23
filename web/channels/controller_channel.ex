defmodule Elvis.ControllerChannel do
  use Phoenix.Channel

  def join("controllers:" <> controller_type, _params, socket) do
    # Don't send the socket with the event because we can't send anything until
    # the channel has been joined (which happens when this function returns)
    # TODO: can use this event to send wakeup calls to the receivers
    Otis.State.Events.notify({:controller_connect, controller_type})
    send self(), :controller_join
    {:ok, socket}
  end

  # def handle_in("list_libraries", _params, socket) do
  #   Otis.State.Events.notify({:list_libraries, socket})
  #   {:noreply, socket}
  # end
  def handle_info(:controller_join, socket) do
    Otis.State.Events.notify({:controller_join, socket})
    {:noreply, socket}
  end
end
