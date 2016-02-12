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
    {:ok, _zone} = Otis.Zones.start(zones, id, %{name: "Something"})
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
    Otis.State.Receiver.delete_all
    Otis.State.Zone.delete_all
    zone_id = Otis.uuid
    receiver_id = Otis.uuid
    channel = spawn(fn ->
      receive do
        :stop -> :ok
      end
    end)
    zone_record = Otis.State.Zone.create!(zone_id, "Something")
    {:ok, zone} = Otis.Zones.create(zone_id, zone_record.name)
    receiver_record = Otis.State.Receiver.create!(zone_record, id: receiver_id, name: "Roger", volume: 1.0)
    {:ok, receiver} = Otis.Receivers.start(
      receiver_id,
      %Otis.Zone{ id: zone_id, pid: zone },
      receiver_record,
      channel,
      %{ "latency" => 0 }
    )
    receiver = %Otis.Receiver{id: receiver_id, pid: receiver}
    on_exit fn ->
      Otis.State.Receiver.delete_all
      Otis.State.Zone.delete_all
    end
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
    expected = Enum.into [receiver, receiver2], HashSet.new
    received = Enum.into receivers, HashSet.new
    assert expected == received
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
    refute Process.alive?(context.receiver.pid)
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
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    :ok = Otis.Zone.add_receiver(zone, receiver)
    event = {:receiver_added, context.zone_id, {receiver.id}}
    assert_receive ^event
    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end

  test "can have its volume set", context do
    Enum.each [context.zone, %Otis.Zone{pid: context.zone, id: context.zone_id}], fn(zone) ->
      {:ok, 1.0} = Otis.Zone.volume(zone)
      Otis.Zone.volume(zone, 0.5)
      {:ok, 0.5} = Otis.Zone.volume(zone)
      Otis.Zone.volume(zone, 1.5)
      {:ok, 1.0} = Otis.Zone.volume(zone)
      Otis.Zone.volume(zone, -1.5)
      {:ok, 0.0} = Otis.Zone.volume(zone)
      Otis.Zone.volume(zone, 1.0)
    end
  end

  test "broadcasts an event when the volume is changed", context do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    {:ok, 1.0} = Otis.Zone.volume(context.zone)
    Otis.Zone.volume(context.zone, 0.5)
    {:ok, 0.5} = Otis.Zone.volume(context.zone)
    event = {:zone_volume_change, context.zone_id, 0.5}
    assert_receive ^event
    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end

  test "does not persist the receivers calculated volume", context do
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    {:ok, 1.0} = Otis.Zone.volume(context.zone)
    Otis.Zone.volume(context.zone, 0.5)
    {:ok, 0.5} = Otis.Zone.volume(context.zone)
    event = {:zone_volume_change, context.zone_id, 0.5}
    assert_receive ^event
    zone = Otis.State.Zone.find context.zone_id
    assert zone.volume == 0.5
    receiver = Otis.State.Receiver.find context.receiver.id
    assert receiver.volume == 1.0
    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end

  require Phoenix.ChannelTest
  use     Phoenix.ChannelTest
  @endpoint Elvis.Endpoint

  test "sets the receivers volume", context do
    # TODO: this actually tests that a websocket connection starts a receiver
    # process with the right id... I need to dupe this test & put it somewhere
    # more meaningful
    :ok = Otis.State.Events.add_handler(MessagingHandler, self)
    id = Otis.uuid
    Otis.Receiver.volume context.receiver, 0.3
    {:ok, socket} = connect(Elvis.ReceiverSocket, %{"id" => id})
    {:ok, _, _} = subscribe_and_join(socket, "receiver:#{id}", %{"latency" => 100})
    assert_receive {:receiver_connected, ^id, _, _}
    assert_receive {:receiver_started, ^id}
    assert_receive {:receiver_joined, ^id, _, _}
    {:ok, receivers} = Otis.Receivers.list
    receiver = Enum.find receivers, fn(r) ->
      r.id == id
    end
    refute is_nil(receiver)

    Otis.Receiver.volume receiver, 0.5

    assert_broadcast "set_volume", %{volume: 0.5}

    Otis.Zone.volume context.zone, 0.1
    zone_id = context.zone_id
    assert_receive {:zone_volume_change, ^zone_id, 0.1}

    assert_broadcast "set_volume", %{volume: 0.05}

    Otis.State.Events.remove_handler(MessagingHandler, self)
    assert_receive :remove_messaging_handler, 100
  end
end
