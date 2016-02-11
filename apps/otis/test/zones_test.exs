defmodule ZonesTest do
  use ExUnit.Case

  @moduletag :zones

  def zone_ids(zones) do
    Enum.map(Otis.Zones.list!(zones), fn(pid) -> {:ok, id} = Otis.Zone.id(pid); id end)
  end

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
    id = Otis.uuid
    {:ok, zone} = Otis.Zones.create(zones, id, "A Zone")
    {:ok, list} = Otis.Zones.list(zones)
    assert list == [zone]
  end

  test "broadcasts an event when a zone is added", %{zones: zones} do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    id = Otis.uuid
    {:ok, _zone} = Otis.Zones.create(zones, id, "My New Zone")
    assert_receive {:zone_added, ^id, %{name: "My New Zone"}}, 200
    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end

  test "broadcasts an event when a zone is removed", %{zones: zones} do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    id = Otis.uuid
    {:ok, zone} = Otis.Zones.create(zones, id, "My New Zone")
    assert_receive {:zone_added, ^id, %{name: "My New Zone"}}, 200

    Otis.Zones.destroy!(zones, id)
    assert_receive {:zone_removed, ^id}, 200
    assert Process.alive?(zone) == false

    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end

  test "doesn't broadcast an event when starting a zone", %{zones: zones} do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)

    id = Otis.uuid
    {:ok, _zone} = Otis.Zones.start(zones, id, "Something")
    refute_receive {:zone_added, ^id, _}

    assert zone_ids(zones) == [id]

    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end
end


defmodule Otis.ZoneTest do
  use ExUnit.Case

  @moduletag :zone

  setup do
    zone_id = Otis.uuid
    receiver_id = Otis.uuid
    channel = spawn(fn ->
      receive do
        :stop -> :ok
      end
    end)
    {:ok, zone} = Otis.Zone.start_link(zone_id)
    {:ok, receiver} = Otis.Receivers.start(
      receiver_id,
      %Otis.Zone{ id: zone_id, pid: zone },
      %Otis.State.Receiver{ id: receiver_id, name: "Receiver", volume: 1 },
      channel,
      %{ "latency" => 0 }
    )
    receiver = %Otis.Receiver{id: receiver_id, pid: receiver}
    {:ok, zone: zone, receiver: receiver, zone_id: zone_id, channel: channel}
  end

  test "gives its id", %{zone: zone, zone_id: zone_id} do
    {:ok, id} = Otis.Zone.id(zone)
    assert id == zone_id
  end

  test "starts with the assigned receiver", %{zone: zone, receiver: receiver} do
    {:ok, receivers} = Otis.Zone.receivers(zone)
    assert receivers == [receiver]
  end

  test "allows you to add a receiver", %{zone: zone, receiver: receiver} = context do
    receiver_id = Otis.uuid
    {:ok, receiver2} = Otis.Receiver.start_link(
      receiver_id,
      %Otis.Zone{ id: context.zone_id, pid: zone },
      %Otis.State.Receiver{ id: receiver_id, name: "Receiver 2", volume: 1 },
      self,
      %{ "latency" => 0 }
    )
    receiver2 = %Otis.Receiver{id: receiver_id, pid: receiver2}
    :ok = Otis.Zone.add_receiver(zone, receiver2)
    {:ok, receivers} = Otis.Zone.receivers(zone)
    assert receivers == [receiver, receiver2]
  end

  test "ignores duplicate receivers", %{zone: zone, receiver: receiver} do
    :ok = Otis.Zone.add_receiver(zone, receiver)
    {:ok, receivers} = Otis.Zone.receivers(zone)
    assert receivers == [receiver]
  end

  test "removes receiver when it stops", context do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    send context.channel, :stop
    receiver_id = context.receiver.id
    assert_receive {:receiver_disconnected, ^receiver_id}
    {:ok, receivers} = Otis.Zone.receivers(context.zone)
    assert receivers == []
    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
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

  test "broadcasts an event when a receiver is added", %{zone: zone, receiver: receiver} = context do
    :ok = Otis.State.Events.add_handler(TestHandler, [])
    :ok = Otis.Zone.add_receiver(zone, receiver)
    messages = Otis.State.Events.call(TestHandler, :messages)
    assert messages == [{:receiver_added, context.zone_id, {receiver.id}}]
    Otis.State.Events.remove_handler(TestHandler)
  end
end
