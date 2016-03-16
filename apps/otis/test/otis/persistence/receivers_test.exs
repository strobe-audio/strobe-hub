defmodule Otis.Persistence.ReceiversTest do
  use    ExUnit.Case
  alias  Otis.Receivers
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
    _record = Otis.State.Receiver.create!(zone, id: id, name: "Receiver", volume: 0.34)
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => (0.34 * context.zone_volume) }
  end

  test "receiver volume changes get persisted to the db", context do
    id = Otis.uuid
    zone = Otis.State.Zone.find(context.zone.id)
    _record = Otis.State.Receiver.create!(zone, id: id, name: "Receiver", volume: 0.34)
    _mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    Otis.State.Events.sync_notify {:receiver_volume_change, id, 0.98}
    assert_receive {:receiver_volume_change, ^id, 0.98}
    record = Otis.State.Receiver.find id
    assert record.volume == 0.98
  end

  test "receivers get attached to the assigned zone", context do
    id = Otis.uuid
    zone = Otis.State.Zone.find(context.zone.id)
    _record = Otis.State.Receiver.create!(zone, id: id, name: "Receiver", volume: 0.34)
    _mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = Receivers.receiver(id)
    {:ok, receivers} = Otis.Zone.receivers context.zone
    assert receivers == [receiver]
  end

  test "receiver zone changes get persisted", context do
    id = Otis.uuid
    zone = Otis.State.Zone.find(context.zone.id)
    _record = Otis.State.Receiver.create!(zone, id: id, name: "Receiver", volume: 0.34)
    _mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = Receivers.receiver(id)
    {:ok, receivers} = Otis.Zone.receivers context.zone
    assert receivers == [receiver]

    zone1_id = context.zone.id
    zone2_id = Otis.uuid
    {:ok, zone2} = Otis.Zones.create(zone2_id, "Froggy")
    zone2 = %Otis.Zone{pid: zone2, id: id}
    assert_receive {:zone_added, ^zone2_id, _}

    Otis.Zone.add_receiver zone2, receiver
    assert_receive {:receiver_removed, ^zone1_id, ^id}
    assert_receive {:receiver_added, ^zone2_id, ^id}
    record = Otis.State.Receiver.find id
    assert record.zone_id == zone2_id
  end
end
