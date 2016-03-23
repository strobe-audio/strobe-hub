defmodule Elvis.Events.Broadcast do
  use     GenEvent
  require Logger

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
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

  # def handle_event({:receiver_volume_change, _, _} = event, state) do
  #   broadcast!(event)
  #   {:ok, state}
  # end
  def handle_event(event, state) do
    IO.inspect [:broadcast?, event]
    {:ok, state}
  end

  defp broadcast!(event, args) do
    msg = Map.put(args, :event, event)
    Elvis.Endpoint.broadcast!("controllers:browser", event, msg)
  end
end
