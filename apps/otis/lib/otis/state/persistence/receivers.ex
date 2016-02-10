
defmodule Otis.State.Persistence.Receivers do
  use     GenEvent
  require Logger

  alias Otis.State.Receiver
  alias Otis.State.Zone

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:receiver_connected, id, channel, connection_info} = e, state) do
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

    Otis.State.Repo.transaction(fn ->
      id |> receiver |> receiver_connected(id, channel, connection_info)
    end)
    {:ok, state}
  end
  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp receiver(id) do
    Receiver.find(id, preload: :zone)
  end

  # if this receiver is not in the db, receiver at this point is nil
  defp receiver_connected(nil, id, channel, connection_info) do
    receiver = create_receiver(zone, id)
    receiver_connected(receiver, id, channel, connection_info)
  end
  defp receiver_connected(receiver, id, channel, connection_info) do
    zone = zone(receiver) |> zone_process
    Otis.Receivers.start(id, zone, receiver, channel, connection_info)
  end

  defp create_receiver(zone, id) do
    Receiver.create!(zone, id: id, name: invented_name(id))
  end

  defp zone do
    Zone.default
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

