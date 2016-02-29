defmodule RecieversTest do
  use ExUnit.Case

  def start_receiver(context) do
    receiver_id = Otis.uuid
    channel = spawn(fn ->
      receive do
        :stop -> :ok
      end
    end)
    zone = Otis.State.Zone.find(context.zone.id)
    record = Otis.State.Receiver.create!(zone, id: receiver_id, name: "Receiver", volume: 1.0)
    {:ok, receiver} = Otis.Receivers.start(context.recs,
      receiver_id,
      context.zone,
      record,
      channel,
      %{ "latency" => 0 }
    )
    %Otis.Receiver{id: receiver_id, pid: receiver}
  end

  setup do
    MessagingHandler.attach
    Otis.State.Zone.delete_all
    Otis.State.Receiver.delete_all
    {:ok, recs} = Otis.Receivers.start_link(:receivers_test)
    on_exit fn ->
      Otis.State.Receiver.delete_all
      Otis.State.Zone.delete_all
      Process.exit(recs, :kill)
    end
    zone_id = Otis.uuid
    record = Otis.State.Zone.create!(zone_id, "Something")
    {:ok, pid} = Otis.Zones.create(zone_id, record.name)
    zone = %Otis.Zone{ id: zone_id, pid: pid }
    {:ok, recs: recs, zone: zone}
  end

  test "allows for the adding of a receiver", context do
    receiver = start_receiver(context)
    {:ok, list } = Otis.Receivers.list(context.recs)
    assert list == [receiver]
  end

  test "lets you retrieve a receiver by id", context do
    receiver = start_receiver(context)
    {:ok, found } = Otis.Receivers.find(context.recs,receiver.id)
    assert found == receiver
  end

  test "returns :error if given an invalid id", %{recs: recs} do
    result = Otis.Receivers.find(recs, "receiver-2")
    assert result == :error
  end

  test "broadcasts an event on volume change", context do
    receiver = start_receiver(context)

    Otis.Receiver.volume receiver, 0.33
    event = {:receiver_volume_change, receiver.id, 0.33}
    assert_receive ^event
  end

  test "updates the persisted receiver volume", context do
    receiver = start_receiver(context)

    Otis.Receiver.volume receiver, 0.33
    event = {:receiver_volume_change, receiver.id, 0.33}
    assert_receive ^event

    record = Otis.State.Receiver.find receiver.id

    assert record.volume == 0.33
  end

  test "correctly casts integer volumes", context do
    receiver = start_receiver(context)

    Otis.Receiver.volume receiver, 1
    event = {:receiver_volume_change, receiver.id, 1.0}
    assert_receive ^event

    record = Otis.State.Receiver.find receiver.id

    assert record.volume == 1.0
  end

  require Phoenix.ChannelTest
  use     Phoenix.ChannelTest
  @endpoint Elvis.Endpoint

  test "sets the receivers volume on startup", context do
    # TODO: this actually tests that a websocket connection starts a receiver
    # process with the right id... I need to dupe this test & put it somewhere
    # more meaningful
    Otis.Zone.volume context.zone, 0.1
    assert_receive {:zone_volume_change, _, 0.1}
    id = Otis.uuid
    {:ok, socket} = connect(Elvis.ReceiverSocket, %{"id" => id})
    {:ok, _, _} = subscribe_and_join(socket, "receiver:#{id}", %{"latency" => 100})
    assert_receive {:receiver_connected, ^id, _, _}
    assert_receive {:receiver_started, ^id}
    assert_receive {:receiver_joined, ^id, _, _}
    assert_receive {:receiver_added, _, {^id}}
    {:ok, receivers} = Otis.Receivers.list
    receiver = Enum.find receivers, fn(r) ->
      r.id == id
    end
    refute is_nil(receiver)

    assert_broadcast "join_zone", %{volume: 0.1}
  end
end

