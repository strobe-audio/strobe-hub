defmodule Elvis.Events.Broadcast do
  use     GenEvent
  require Logger

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:zone_finished, zone_id}, state) do
    broadcast!("zone_play_pause", %{zoneId: zone_id, status: :stop})
    {:ok, state}
  end

  def handle_event({:source_changed, zone_id, nil, new_source_id}, state) do
    {:ok, state}
  end
  def handle_event({:source_changed, zone_id, old_source_id, new_source_id}, state) do
    broadcast!("source_changed", %{zoneId: zone_id, removeSourceIds: [old_source_id]})
    {:ok, state}
  end

  def handle_event({:source_progress, zone_id, source_id, progress_ms, duration_ms}, state) do
    broadcast!("source_progress", %{zoneId: zone_id, sourceId: source_id, progress: progress_ms, duration: duration_ms})
    {:ok, state}
  end
  def handle_event({:zone_play_pause, zone_id, status}, state) do
    broadcast!("zone_play_pause", %{zoneId: zone_id, status: status})
    {:ok, state}
  end

  def handle_event({event, zone_id, receiver_id}, state)
  when event in [:receiver_added, :receiver_removed] do
    broadcast!(to_string(event), %{zoneId: zone_id, receiverId: receiver_id})
    {:ok, state}
  end

  def handle_event({:receiver_volume_change, id, volume} = event, state) do
    broadcast!("volume_change", %{ id: id, target: "receiver", volume: volume })
    {:ok, state}
  end

  def handle_event({:zone_volume_change, id, volume} = event, state) do
    broadcast!("volume_change", %{ id: id, target: "zone", volume: volume })
    {:ok, state}
  end

  def handle_event(event, state) do
    IO.inspect [:broadcast?, event]
    {:ok, state}
  end

  defp broadcast!(event, msg) do
    # msg = Map.put(args, :event, event)
    Elvis.Endpoint.broadcast!("controllers:browser", event, msg)
  end
end
