defmodule Otis.Receivers.DataConnection do
  use Otis.Receivers.Protocol, type: :data

  @ping_interval 2_000

  def handle_cast({:data, _data}, %S{muted: true} = state) do
    {:noreply, state}
  end
  def handle_cast({:data, data}, state) do
    send_data_handling_errors(data, state)
  end

  def handle_call({:mute, muted}, _from, state) do
    {:reply, :ok, %S{ state | muted: muted }}
  end

  def handle_call(_msg, _from , state) do
    {:reply, :ok, state}
  end

  defp initial_settings, do: %{}
  defp receiver_alive(state), do: state

  defp monitor_connection(state) do
    tref = Process.send_after(self(), :ping, @ping_interval)
    %S{state | monitor_timeout: tref}
  end

  defp reset_ping(state) do
    state |> cancel_ping |> monitor_connection()
  end
  defp cancel_ping(%S{monitor_timeout: nil} = state), do: state
  defp cancel_ping(%S{monitor_timeout: tref} = state) do
    Process.cancel_timer(tref)
    %S{state | monitor_timeout: nil}
  end

  defp send_ping(state) do
    ["PING"] |> send_data_handling_errors(state)
  end

  defp send_data_handling_errors(data, state) do
    case send_data(data, state) do
      :ok ->
        {:noreply, reset_ping(state)}
      {:error, _reason} ->
        close_and_disconnect(state, :offline)
        {:stop, :normal, cancel_ping(state)}
    end
  end
end
