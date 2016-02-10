defmodule Elvis.ReceiverChannel do
  use     Phoenix.Channel
  require Logger

  def join("receiver:" <> receiver_id, connection_info, socket) do
    Logger.debug "JOIN receiver #{inspect socket.assigns} #{inspect connection_info}"
    Otis.State.Events.notify({
      :receiver_connected,
      receiver_id(socket),
      self,
      connection_info
    })
    # Otis.Receivers.joined(self, receiver_id(socket), connection_info)
    {:ok, socket}
  end

  # def terminate(reason, socket) do
  #   Logger.debug "LEAVE #{inspect reason} #{inspect socket}"
  #   # {:ok, socket }
  #   :ok
  # end

  def handle_info(msg, state) do
    IO.inspect [:info, msg, state]
    {:noreply, state}
  end

  defp receiver_id(socket) do
    socket.assigns[:id]
  end
end
