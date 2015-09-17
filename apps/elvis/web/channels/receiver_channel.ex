defmodule Elvis.ReceiverChannel do
  use     Phoenix.Channel
  require Logger

  def join("receiver:" <> _receiver_id, auth_msg, socket) do
    Logger.debug "JOIN receiver #{inspect _receiver_id} #{inspect auth_msg}"
    {:ok, socket}
  end
end
