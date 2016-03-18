defmodule Otis.Receivers.DataConnection do
  use Otis.Receivers.Protocol, type: :data

  defp initial_settings, do: %{}
  defp monitor_connection(state), do: state
end
