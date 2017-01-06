defmodule Otis.Receivers.DataConnection do
  use Otis.Receivers.Protocol, type: :data

  def handle_cast({:data, data}, state) do
    case send_data(data, state) do
      :ok ->
        {:noreply, state}
      {:error, reason} ->
        disconnect(state, reason)
        {:stop, :normal, state}
    end
  end

  defp initial_settings, do: %{}
  defp monitor_connection(state), do: state
end
