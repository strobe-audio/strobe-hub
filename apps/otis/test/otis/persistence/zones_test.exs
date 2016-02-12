defmodule Otis.Persistence.ZonesTest do
  use   ExUnit.Case

  setup_all do
    on_exit fn ->
      Otis.State.Zone.delete_all
    end
    :ok
  end

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    :ok
  end


  test "it persists a new zone" do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)

    assert Otis.State.Zone.all == []
    id = Otis.uuid
    name = "A new zone"
    {:ok, _zone} = Otis.Zones.create(id, name)
    assert_receive {:zone_added, ^id, %{name: ^name}}, 200
    zones = Otis.State.Zone.all
    assert length(zones) == 1
    [%Otis.State.Zone{id: ^id, name: ^name}] = zones

    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end

  test "it deletes a record when a zone is removed" do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)

    assert Otis.State.Zone.all == []
    id = Otis.uuid
    name = "A new zone"
    {:ok, _zone} = Otis.Zones.create(id, name)
    assert_receive {:zone_added, ^id, %{name: ^name}}, 200

    :ok = Otis.Zones.destroy!(id)
    assert_receive {:zone_removed, ^id}, 200

    zones = Otis.State.Zone.all
    assert length(zones) == 0

    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end

  test "doesn't persist an existing zone" do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)

    assert Otis.State.Zone.all == []
    id = Otis.uuid
    name = "A new zone"
    {:ok, zone} = Otis.Zones.create(id, name)
    assert_receive {:zone_added, ^id, %{name: ^name}}, 200


    Otis.Zones.Supervisor.stop_zone(zone)
    refute Process.alive?(zone)

    {:ok, _zone} = Otis.Zones.create(id, name)

    zones = Otis.State.Zone.all
    assert length(zones) == 1
    [%Otis.State.Zone{id: ^id, name: ^name}] = zones

    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end

  test "initializes a zone with the persisted volume", _context do
    id = Otis.uuid
    zone = Otis.State.Zone.create!(id, "Donal")
    Otis.State.Zone.volume(zone, 0.11)
    zone = Otis.State.Zone.find(id)
    assert zone.volume == 0.11

    {:ok, pid} = Otis.Zones.start(id, zone)

    {:ok, 0.11} = Otis.Zone.volume(pid)
  end

  test "persists volume changes" do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)

    assert Otis.State.Zone.all == []
    id = Otis.uuid
    name = "A new zone"
    {:ok, zone} = Otis.Zones.create(id, name)
    assert_receive {:zone_added, ^id, %{name: ^name}}, 200

    Otis.Zone.volume(zone, 0.33)
    assert_receive {:zone_volume_change, ^id, 0.33}

    zone = Otis.State.Zone.find(id)

    assert zone.volume == 0.33

    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end
end
