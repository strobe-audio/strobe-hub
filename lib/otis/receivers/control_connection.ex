defmodule Otis.Receivers.ControlConnection do
  use Otis.Receivers.Protocol, type: :ctrl

  @monitor_interval 1000
  @timeout_interval 4000

  def set_volume(connection, volume) do
    GenServer.cast(connection, {:set_volume, volume})
  end

  def set_volume(connection, volume, multiplier) do
    GenServer.cast(connection, {:set_volume, volume, multiplier})
  end

  def get_volume(connection) do
    GenServer.call(connection, :get_volume)
  end

  def set_volume_multiplier(connection, multiplier) do
    GenServer.cast(connection, {:set_volume_multiplier, multiplier})
  end

  def get_volume_multiplier(connection) do
    GenServer.call(connection, :get_volume_multiplier)
  end

  def handle_cast({:set_volume, volume}, state) do
    state = change_volume(state, [volume: volume])
    {:noreply, state}
  end

  def handle_cast({:set_volume, volume, multiplier}, state) do
    state = change_volume(state, [volume: volume, volume_multiplier: multiplier])
    {:noreply, state}
  end

  def handle_cast({:set_volume_multiplier, multiplier}, state) do
    state = change_volume(state, [volume_multiplier: multiplier])
    {:noreply, state}
  end

  def handle_cast({:command, command}, state) do
    %{ command: command } |> send_command(state)
    {:noreply, state}
  end

  def handle_call(:get_volume, _from, state) do
    {:reply, Map.fetch(state.settings, :volume), state}
  end

  def handle_call(:get_volume_multiplier, _from, state) do
    {:reply, Map.fetch(state.settings, :volume_multiplier), state}
  end

  def handle_info(:start_monitor, state) do
    {:noreply, send_ping(state)}
  end

  def handle_info(:timeout, state) do
    close_and_disconnect(state, :offline)
    {:stop, :normal, cancel_timeout(state)}
  end

  # the volume here must match the default volume setting in the audio
  # driver C code
  defp initial_settings, do: %{volume: 0.0, volume_multiplier: 1.0}

  defp change_volume(state, values) do
    v1 = Map.take(state.settings, [:volume, :volume_multiplier])
    settings = Enum.into(values, state.settings)
    v2 = Map.take(settings, [:volume, :volume_multiplier])
    %S{state | settings: settings} |> monitor_volume(values, v1, v2)
  end

  defp monitor_volume(state, _values, volume, volume) do
    state
  end
  defp monitor_volume(state, values, _initial_volume, final_volume) do
    volume = calculated_volume(final_volume)
    %{ volume: volume } |> send_command(state)
    notify_volume(state, values)
  end

  defp notify_volume(%S{settings: settings} = state, values) do
    # Don't send an event when changing the multiplier as the multiplier is a
    # channel-level property and events for it are emitted there.
    if Keyword.has_key?(values, :volume) do
      Otis.State.Events.notify({:receiver_volume_change, [state.id, settings.volume]})
    end
    state
  end

  defp calculated_volume(%S{settings: settings} = _state) do
    calculated_volume(settings)
  end

  # https://www.dr-lex.be/info-stuff/volumecontrols.html
  defp calculated_volume(%{volume: volume, volume_multiplier: multiplier}) do
    case volume * multiplier do
      0.0 -> 0.0
      1.0 -> 1.0
      v when v < 0.1 -> logarithmic_volume(v) * (v * 10)
      v -> logarithmic_volume(v)
    end |> Otis.sanitize_volume
  end

  defp logarithmic_volume(volume) do
    0.001 * :math.exp(volume * :math.log(1000.0))
  end

  defp monitor_connection(state) do
    Process.send_after(self(), :start_monitor, @monitor_interval)
    state
  end

  defp send_ping(state) do
    %{ ping: :erlang.unique_integer([:positive, :monotonic]) } |> send_command(state)
    ref = Process.send_after(self(), :timeout, @timeout_interval)
    %S{ state | monitor_timeout: ref  }
  end

  defp receiver_alive(state) do
    state |> cancel_timeout |> monitor_connection
  end

  defp cancel_timeout(%S{monitor_timeout: nil} = state) do
    state
  end
  defp cancel_timeout(%S{monitor_timeout: ref} = state) do
    Process.cancel_timer(ref)
    %S{ state | monitor_timeout: nil }
  end
end
