defmodule ZonesTest do
  use ExUnit.Case

  @moduletag :zones

  setup do
    {:ok, zones} = Otis.Zones.start_link(:test_zones)
    {:ok, zones: zones}
  end

  test "allows for the adding of a zone", %{zones: zones} do
    id = Otis.uuid
    {:ok, zone} = Otis.Zones.create(zones, id, "Downstairs")
    {:ok, list } = Otis.Zones.list(zones)
    assert list == [zone]
  end

  test "lets you retrieve a zone by id", %{zones: zones} do
    id = Otis.uuid
    {:ok, zone} = Otis.Zones.create(zones, id, "Downstairs")
    {:ok, found } = Otis.Zones.find(zones, id)
    assert found == zone
  end

  test "returns :error if given an invalid id", %{zones: zones} do
    result = Otis.Zones.find(zones, "zone-2")
    assert result == :error
  end

  test "starts and adds the given zone", %{zones: zones} do
    {:ok, zone} = Otis.Zones.create(zones, "1", "A Zone")
    {:ok, list} = Otis.Zones.list(zones)
    assert list == [zone]
  end
end


defmodule Otis.ZoneTest do
  use ExUnit.Case

  @moduletag :zone

  setup do
    {:ok, zone} = Otis.Zone.start_link(:zone_1, "Downstairs")
    {:ok, receiver} = Otis.Receiver.start_link(self, "receiver_2", %{ "latency" => 0 })
    {:ok, zone: zone, receiver: receiver}
  end

  test "gives its name", %{zone: zone} do
    {:ok, name} = Otis.Zone.name(zone)
    assert name == "Downstairs"
  end

  test "gives its id", %{zone: zone} do
    {:ok, id} = Otis.Zone.id(zone)
    assert id == "zone_1"
  end

  test "starts with an empty receiver list", %{zone: zone} do
    {:ok, receivers} = Otis.Zone.receivers(zone)
    assert receivers == []
  end

  test "allows you to add a receiver", %{zone: zone, receiver: receiver} do
    :ok = Otis.Zone.add_receiver(zone, receiver)
    {:ok, receivers} = Otis.Zone.receivers(zone)
    assert receivers == [receiver]
  end

  test "ignores duplicate receivers", %{zone: zone, receiver: receiver} do
    :ok = Otis.Zone.add_receiver(zone, receiver)
    :ok = Otis.Zone.add_receiver(zone, receiver)
    {:ok, receivers} = Otis.Zone.receivers(zone)
    assert receivers == [receiver]
  end

  test "allows you to remove a receiver", %{zone: zone, receiver: receiver} do
    :ok = Otis.Zone.add_receiver(zone, receiver)
    :ok = Otis.Zone.remove_receiver(zone, receiver)
    {:ok, receivers} = Otis.Zone.receivers(zone)
    assert receivers == []
  end

  test "allows you to query the play pause state", %{zone: zone} do
    {:ok, state} = Otis.Zone.state(zone)
    assert state == :stop
  end

  test "allows you to toggle the play pause state", %{zone: zone} do

    {:ok, state} = Otis.Zone.play_pause(zone)
    assert state == :play
    {:ok, state} = Otis.Zone.play_pause(zone)
    assert state == :stop
  end

  test "broadcasts an event when a receiver is added", %{zone: zone, receiver: receiver} do
    :ok = Otis.State.Events.add_handler(TestHandler, [])
    :ok = Otis.Zone.add_receiver(zone, receiver)
    messages = Otis.State.Events.call(TestHandler, :messages)
    assert messages == [{:receiver_added, "zone_1", {:receiver_2}}]
    Otis.State.Events.remove_handler(TestHandler)
  end

  test "broadcasts an event when a zone is added", _context do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    id = Otis.uuid
    {:ok, _zone} = Otis.Zones.create(id, "My New Zone")
    assert_receive {:zone_added, ^id, %{name: "My New Zone"}}, 200
    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end
  test "broadcasts an event when a zone is removed", _context do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    id = Otis.uuid
    {:ok, zone} = Otis.Zones.create(id, "My New Zone")
    assert_receive {:zone_added, ^id, %{name: "My New Zone"}}, 200


    Otis.Zones.remove_zone(id)
    assert_receive {:zone_removed, ^id}, 200
    assert Process.alive?(zone) == false
    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end
end
