defmodule Otis.State.Persistence.Configuration do
  use     GenEvent
  require Logger

  alias Otis.State.Setting

  @keys [:wifi]

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:receiver_connected, [id, recv]}, state) do
    receiver_connected(id, recv)
    {:ok, state}
  end
  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp receiver_connected(id, receiver) do
    Enum.each(@keys, &configure_receiver(&1, id, receiver))
  end

  defp configure_receiver(key, _id, receiver) do
    Setting.namespace(key) |> send_configuration(key, receiver)
  end

  defp send_configuration(:error, _key, _receiver), do: nil
  defp send_configuration({:ok, settings}, key, receiver) do
    Otis.Receiver.configure(receiver, %{ key => settings })
  end
end
