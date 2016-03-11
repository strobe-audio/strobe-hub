defmodule ZonesTest do
  use ExUnit.Case

  @moduletag :zones

  def zone_ids(zones) do
    Enum.map(Otis.Zones.list!(zones), fn(pid) -> {:ok, id} = Otis.Zone.id(pid); id end)
  end

  setup do
    MessagingHandler.attach
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
    id = Otis.uuid
    {:ok, zone} = Otis.Zones.create(zones, id, "A Zone")
    {:ok, list} = Otis.Zones.list(zones)
    assert list == [zone]
  end

  test "broadcasts an event when a zone is added", %{zones: zones} do
    id = Otis.uuid
    {:ok, _zone} = Otis.Zones.create(zones, id, "My New Zone")
    assert_receive {:zone_added, ^id, %{name: "My New Zone"}}, 200
  end

  test "broadcasts an event when a zone is removed", %{zones: zones} do
    id = Otis.uuid
    {:ok, zone} = Otis.Zones.create(zones, id, "My New Zone")
    assert_receive {:zone_added, ^id, %{name: "My New Zone"}}, 200

    Otis.Zones.destroy!(zones, id)
    assert_receive {:zone_removed, ^id}, 200
    assert Process.alive?(zone) == false
  end

  test "doesn't broadcast an event when starting a zone", %{zones: zones} do
    id = Otis.uuid
    {:ok, _zone} = Otis.Zones.start(zones, id, %{name: "Something"})
    refute_receive {:zone_added, ^id, _}

    assert zone_ids(zones) == [id]
  end
end
