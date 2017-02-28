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
  def handle_event({:retrieve_settings, ["otis", socket]}, state) do
    {:ok, settings} = Otis.Settings.current
    Otis.State.Events.notify({:application_settings, [:otis, settings, socket]})
    {:ok, state}
  end
  def handle_event({:save_settings, [%{"application" => "otis", "namespaces" => ns} = _settings]}, state) do
    ns |> save_settings
    {:ok, state}
  end
  def handle_event({:save_settings, [_settings]}, state) do
    {:ok, state}
  end

  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp receiver_connected(id, receiver) do
    Enum.each(@keys, &configure_receiver(&1, id, receiver))
  end

  defp configure_receiver(key, _id, receiver) do
    Setting.namespace(:otis, key) |> send_configuration(key, receiver)
  end

  defp send_configuration(:error, _key, _receiver), do: nil
  defp send_configuration({:ok, settings}, key, receiver) do
    Otis.Receiver.configure(receiver, %{ key => settings })
  end

  defp save_settings([]) do
  end
  defp save_settings([%{"application" => "otis", "fields" => fields} = _settings | rest]) do
    Otis.Settings.save_fields(fields)
    save_settings(rest)
  end
  defp save_settings([_settings | rest]) do
    save_settings(rest)
  end
end
