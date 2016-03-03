defmodule Otis.Persistence.ReceiversTest do
  use    ExUnit.Case
  alias  Otis.ReceiverSocket, as: RS
  alias  Otis.Receiver2, as: Receiver
  import MockReceiver

  setup do
    MessagingHandler.attach
    id = Otis.uuid
    {:ok, zone} = Otis.Zones.create(id, "Fishy")
    zone = %Otis.Zone{pid: zone, id: id}
    assert_receive {:zone_added, ^id, _}
    zone_volume = 0.56
    Otis.Zone.volume zone, zone_volume
    {:ok, zone: zone, zone_volume: zone_volume}
  end

  test "receivers get their volume set from the db", context do
    id = Otis.uuid
    zone = Otis.State.Zone.find(context.zone.id)
    record = Otis.State.Receiver.create!(zone, id: id, name: "Receiver", volume: 0.34)
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => (0.34 * context.zone_volume) }
  end

  test "receiver volume changes get persisted to the db", context do
    id = Otis.uuid
    zone = Otis.State.Zone.find(context.zone.id)
    record = Otis.State.Receiver.create!(zone, id: id, name: "Receiver", volume: 0.34)
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    Otis.State.Events.sync_notify {:receiver_volume_change, id, 0.98}
    assert_receive {:receiver_volume_change, ^id, 0.98}
    record = Otis.State.Receiver.find id
    assert record.volume == 0.98
  end

  test "receivers get attached to the assigned zone", context do
    id = Otis.uuid
    zone = Otis.State.Zone.find(context.zone.id)
    record = Otis.State.Receiver.create!(zone, id: id, name: "Receiver", volume: 0.34)
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = RS.receiver(id)
    {:ok, receivers} = Otis.Zone.receivers context.zone
    assert receivers == [receiver]
  end
end
