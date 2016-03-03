defmodule Otis.ZoneTest do
  use    ExUnit.Case
  alias  Otis.Receivers
  import MockReceiver

  @moduletag :zone

  setup do
    MessagingHandler.attach
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
    _receiver_record = Otis.State.Receiver.create!(zone_record, id: receiver_id, name: "Roger", volume: 1.0)
    mock = connect!(receiver_id, 1234)
    assert_receive {:receiver_connected, ^receiver_id, _}
    {:ok, receiver} = Receivers.receiver(receiver_id)
    on_exit fn ->
      Otis.State.Receiver.delete_all
      Otis.State.Zone.delete_all
    end
    {:ok,
      zone: zone,
      receiver: receiver,
      zone_id: zone_id,
      channel: channel,
      mock_receiver: mock,
    }
  end

  test "gives its id", %{zone: zone, zone_id: zone_id} do
    {:ok, id} = Otis.Zone.id(zone)
    assert id == zone_id
  end

  test "starts with the assigned receiver", %{zone: zone, receiver: receiver} do
    {:ok, receivers} = Otis.Zone.receivers(zone)
    assert receivers == [receiver]
  end

  test "allows you to add a receiver", %{zone: zone, receiver: receiver} do
    receiver_id = Otis.uuid
    _mock = connect!(receiver_id, 2298)
    assert_receive {:receiver_connected, ^receiver_id, _}
    {:ok, receiver2} = Receivers.receiver(receiver_id)
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
    mock = context.mock_receiver
    receiver_id = context.receiver.id
    :ok = :gen_tcp.close(mock.data_socket)
    assert_receive {:receiver_disconnected, ^receiver_id, _}
    {:ok, receivers} = Otis.Zone.receivers(context.zone)
    assert receivers == []
  end

  test "removes receiver from socket when it stops", context do
    mock = context.mock_receiver
    receiver_id = context.receiver.id
    :ok = :gen_tcp.close(mock.data_socket)
    assert_receive {:receiver_disconnected, ^receiver_id, _}
    {:ok, socket} = Otis.Zone.socket(context.zone)
    {:ok, receivers} = Otis.Zone.Socket.receivers(socket)
    assert receivers == []
  end

  test "sends data to receiver", context do
    mock = context.mock_receiver
    # Receiver.send_data(context.receiver <<"something">>)
    {:ok, socket} = Otis.Zone.socket(context.zone)
    Otis.Zone.Socket.send(socket, 1234, <<"something">>)
    {:ok, data} = data_recv_raw(mock)
    <<
      count     :: size(64)-little-unsigned-integer,
      timestamp :: size(64)-little-signed-integer,
      audio     :: binary
    >> = data
    assert count == 0
    assert timestamp == 1234
    assert audio == <<"something">>
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
    :ok = Otis.Zone.add_receiver(zone, receiver)
    event = {:receiver_added, context.zone_id, {receiver.id}}
    assert_receive ^event
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
    {:ok, 1.0} = Otis.Zone.volume(context.zone)
    Otis.Zone.volume(context.zone, 0.5)
    {:ok, 0.5} = Otis.Zone.volume(context.zone)
    event = {:zone_volume_change, context.zone_id, 0.5}
    assert_receive ^event
  end

  test "does not persist the receivers calculated volume", context do
    {:ok, 1.0} = Otis.Zone.volume(context.zone)
    Otis.Zone.volume(context.zone, 0.5)
    {:ok, 0.5} = Otis.Zone.volume(context.zone)
    event = {:zone_volume_change, context.zone_id, 0.5}
    assert_receive ^event
    zone = Otis.State.Zone.find context.zone_id
    assert zone.volume == 0.5
    receiver = Otis.State.Receiver.find context.receiver.id
    assert receiver.volume == 1.0
  end
end
