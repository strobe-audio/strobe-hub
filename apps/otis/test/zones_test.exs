defmodule ZonesTest do
  use ExUnit.Case

  @moduletag :zones

  setup do
    {:ok, zones} = Otis.Zones.start_link(:test_zones)
    {:ok, zones: zones}
  end


  alias Otis.Zone

  test "allows for the adding of a zone", %{zones: zones} do
    {:ok, zone} = Zone.start_link(:zone_1, "Downstairs")
    Otis.Zones.add(zones, zone)
    {:ok, list } = Otis.Zones.list(zones)
    assert list == [zone]
  end

  test "lets you retrieve a zone by id", %{zones: zones} do
    {:ok, zone} = Zone.start_link(:zone_1, "Downstairs")
    Otis.Zones.add(zones, zone)
    {:ok, found } = Otis.Zones.find(zones, :zone_1)
    assert found == zone
  end

  test "returns :error if given an invalid id", %{zones: zones} do
    result = Otis.Zones.find(zones, "zone-2")
    assert result == :error
  end

  test "starts and adds the given zone", %{zones: zones} do
    {:ok, zone} = Otis.Zones.start_zone(zones, "1", "A Zone")
    {:ok, list} = Otis.Zones.list(zones)
    assert list == [zone]
  end
end


defmodule Otis.ZoneTest do
  use ExUnit.Case

  @moduletag :zone

  setup do
    {:ok, zone} = Otis.Zone.start_link(:zone_1, "Downstairs")
    {:ok, receiver} = Otis.Receiver.start_link(:receiver_1, node)
    {:ok, zone: zone, receiver: receiver}
  end

  test "gives its name", %{zone: zone} do
    {:ok, _name} = Otis.Zone.name(zone)
    assert _name == "Downstairs"
  end

  test "gives its id", %{zone: zone} do
    {:ok, id} = Otis.Zone.id(zone)
    assert id == :zone_1
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
