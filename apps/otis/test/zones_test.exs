defmodule ZonesTest do
  use ExUnit.Case, async: true

  setup do
    # {:ok, sup} = Otis.Zones.Supervisor.start_link(name: Otis.Zones.Supervisor)
    # {:ok, zones} = Otis.Zones.start_link
    zones = Otis.Zones
    {:ok, zones: zones}
  end

  alias Otis.Zone

  test "allows for the adding of a zone", %{zones: zones} do
    {:ok, zone} = Zone.start_link("zone-1", "Downstairs")
    Otis.Zones.add(zones, zone)
    {:ok, list } = Otis.Zones.list(zones)
    assert list == [zone]
  end

  test "lets you retrieve a zone by id", %{zones: zones} do
    {:ok, zone} = Zone.start_link("zone-1", "Downstairs")
    Otis.Zones.add(zones, zone)
    {:ok, found } = Otis.Zones.find(zones, "zone-1")
    assert found == zone
  end

  test "returns :error if given an invalid id", %{zones: zones} do
    result = Otis.Zones.find(zones, "zone-2")
    assert result == :error
  end

  test "starts and adds the given zone", %{zones: zones} do
    {:ok, zone} = Otis.Zones.start_zone("1", "A Zone")
    {:ok, list} = Otis.Zones.list(zones)
    assert list == [zone]
  end
end

defmodule Otis.ZoneTest do
  use ExUnit.Case, async: true

  setup do
    name = "Downstairs"
    {:ok, zone} = Otis.Zone.start_link("zone-1", name)
    {:ok, receiver} = Otis.Receiver.start_link("receiver-1", "Kitchen")
    {:ok, zone: zone, name: name, receiver: receiver}
  end

  test "gives its name", %{zone: zone, name: name} do
    {:ok, _name} = Otis.Zone.name(zone)
    assert _name == name
  end

  test "gives its id", %{zone: zone} do
    {:ok, id} = Otis.Zone.id(zone)
    assert id == "zone-1"
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
end
