
defmodule Otis.State.Persistence.Receivers do
  use     GenEvent
  require Logger

  alias Otis.State.Receiver
  alias Otis.State.Zone

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:receiver_started, id}, state) do
    id |> receiver |> receiver_started(id)
    {:ok, state}
  end
  # = so we have a connection from a receiver
  # = see if we have the given id in the db
  # if yes:
  #   - find id of zone it belongs to
  # if no:
  #   - choose some default zone from the db (first when order by position..)
  # = map id to zone pid
  # = start receiver process using given id & zone etc
  #   - this should be a :create call if the receiver is new
  #   - or a :start call if the receiver existed
  # = once receiver has started it broadcasts an event which arrives back here
  #   and allows us to persist any changes
  # def handle_event({:receiver_connected, id, channel, connection_info}, state) do
  def handle_event({:receiver_connected, id, recv}, state) do
    Otis.State.Repo.transaction(fn ->
      id |> receiver |> receiver_connected(id, recv)
    end)
    {:ok, state}
  end
  def handle_event({:receiver_volume_change, id, volume}, state) do
    Otis.State.Repo.transaction(fn ->
      id |> receiver |> volume_change(id, volume)
    end)
    {:ok, state}
  end
  def handle_event({:receiver_added, zone_id, id}, state) do
    Otis.State.Repo.transaction(fn ->
      id |> receiver |> zone_change(id, zone_id)
    end)
    {:ok, state}
  end
  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp receiver(id) do
    Receiver.find(id, preload: :zone)
  end

  defp receiver_started(nil, _id) do
    # Can happen in tests
  end
  defp receiver_started(receiver, id) do
    Otis.State.Events.notify({:receiver_joined, id, receiver.zone_id, receiver})
  end

  # if neither the receiver nor the given zone are in the db, receiver at this
  # point is nil
  defp receiver_connected(:error, _id, _recv) do
  end
  defp receiver_connected(nil, id, receiver) do
    receiver_state = create_receiver(zone, id)
    receiver_connected(receiver_state, id, receiver)
  end
  defp receiver_connected(receiver_state, _id, receiver) do
    zone = zone(receiver_state) |> zone_process
    Otis.Receiver.configure_and_join_zone(receiver, receiver_state, zone)
  end

  defp volume_change(nil, id, _volume) do
    Logger.warn "Volume change for unknown receiver #{ id }"
  end
  defp volume_change(receiver, _id, volume) do
    Receiver.volume(receiver, volume)
  end

  defp zone_change(nil, id, zone_id) do
    Logger.warn "Zone change for unknown receiver #{ id } -> zone #{ zone_id }"
  end
  defp zone_change(receiver, id, zone_id) do
    Receiver.zone(receiver, zone_id)
  end

  defp create_receiver(nil, id) do
    Logger.warn "Attempt to create receiver #{id} with a nil zone"
    :error
  end
  defp create_receiver(zone, id) do
    Receiver.create!(zone, id: id, name: invented_name(id))
  end

  defp zone do
    Zone.default_for_receiver
  end
  defp zone(receiver) do
    receiver.zone
  end

  defp zone_process(zone) do
    pid = zone.id |> Otis.Zones.find!
    %Otis.Zone{id: zone.id, pid: pid}
  end

  defp invented_name(id) do
    "Receiver #{id}"
  end
end

