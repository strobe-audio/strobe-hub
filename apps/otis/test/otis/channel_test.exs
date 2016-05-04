defmodule Otis.ChannelTest do
  use    ExUnit.Case
  alias  Otis.Receivers
  import MockReceiver

  @moduletag :channel

  setup do
    MessagingHandler.attach
    Otis.State.Receiver.delete_all
    Otis.State.Channel.delete_all
    channel_id = Otis.uuid
    receiver_id = Otis.uuid

    channel = spawn(fn ->
      receive do
        :stop -> :ok
      end
    end)

    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    {:ok, channel} = Otis.Channels.create(channel_id, channel_record.name)
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: receiver_id, name: "Roger", volume: 1.0)
    mock = connect!(receiver_id, 1234)
    assert_receive {:receiver_connected, ^receiver_id, _}
    {:ok, receiver} = Receivers.receiver(receiver_id)
    on_exit fn ->
      Otis.State.Receiver.delete_all
      Otis.State.Channel.delete_all
    end
    {:ok,
      channel: channel,
      receiver: receiver,
      channel_id: channel_id,
      channel: channel,
      mock_receiver: mock,
    }
  end

  test "gives its id", %{channel: channel, channel_id: channel_id} do
    {:ok, id} = Otis.Channel.id(channel)
    assert id == channel_id
  end

  test "starts with the assigned receiver", %{channel: channel, receiver: receiver} do
    {:ok, receivers} = Otis.Channel.receivers(channel)
    assert receivers == [receiver]
  end

  test "allows you to add a receiver", %{channel: channel, receiver: receiver} do
    receiver_id = Otis.uuid
    _mock = connect!(receiver_id, 2298)
    assert_receive {:receiver_connected, ^receiver_id, _}
    {:ok, receiver2} = Receivers.receiver(receiver_id)
    :ok = Otis.Channel.add_receiver(channel, receiver2)
    {:ok, receivers} = Otis.Channel.receivers(channel)
    expected = Enum.into [receiver, receiver2], HashSet.new
    received = Enum.into receivers, HashSet.new
    assert expected == received
  end

  test "allows you to remove a receiver", %{channel: channel, receiver: receiver} do
    receiver_id = Otis.uuid
    mock = connect!(receiver_id, 2298)
    assert_receive {:receiver_connected, ^receiver_id, _}
    {:ok, receiver2} = Receivers.receiver(receiver_id)
    {:ok, receivers} = Otis.Channel.receivers(channel)
    expected = Enum.into [receiver, receiver2], HashSet.new
    received = Enum.into receivers, HashSet.new
    assert expected == received

    channel2_id = Otis.uuid
    {:ok, _channel2} = Otis.Channels.create(channel2_id, "Froggy")
    assert_receive {:channel_added, ^channel2_id, _}
    data_reset(mock)
    Otis.Receivers.attach receiver_id, channel2_id

    assert_receive {:receiver_removed, _, ^receiver_id}

    {:ok, receivers} = Otis.Channel.receivers(channel)
    expected = Enum.into [receiver], HashSet.new
    received = Enum.into receivers, HashSet.new
    assert expected == received
    msg = data_recv_raw(mock)
    assert {:ok, "STOP"} == msg
  end

  test "removes receiver from socket when removed from channel", %{channel: channel, receiver: receiver} do
    receiver_id = Otis.uuid
    _mock = connect!(receiver_id, 2298)
    assert_receive {:receiver_connected, ^receiver_id, _}
    {:ok, receiver2} = Receivers.receiver(receiver_id)
    :ok = Otis.Channel.add_receiver(channel, receiver2)

    {:ok, socket} = Otis.Channel.socket(channel)

    channel2_id = Otis.uuid
    {:ok, _channel2} = Otis.Channels.create(channel2_id, "Froggy")
    assert_receive {:channel_added, ^channel2_id, _}
    Otis.Receivers.attach receiver_id, channel2_id

    assert_receive {:receiver_removed, _, ^receiver_id}

    {:ok, receivers} = Otis.Channel.Socket.receivers(socket)
    assert receivers == [receiver]
  end

  test "ignores duplicate receivers", %{channel: channel, receiver: receiver} do
    :ok = Otis.Channel.add_receiver(channel, receiver)
    {:ok, receivers} = Otis.Channel.receivers(channel)
    assert receivers == [receiver]
  end

  test "removes receiver when it stops", context do
    mock = context.mock_receiver
    receiver_id = context.receiver.id
    :ok = :gen_tcp.close(mock.data_socket)
    assert_receive {:receiver_disconnected, ^receiver_id, _}
    {:ok, receivers} = Otis.Channel.receivers(context.channel)
    assert receivers == []
  end

  test "removes receiver from socket when it stops", context do
    mock = context.mock_receiver
    receiver_id = context.receiver.id
    :ok = :gen_tcp.close(mock.data_socket)
    assert_receive {:receiver_disconnected, ^receiver_id, _}
    {:ok, socket} = Otis.Channel.socket(context.channel)
    {:ok, receivers} = Otis.Channel.Socket.receivers(socket)
    assert receivers == []
  end

  test "sends data to receiver", context do
    mock = context.mock_receiver
    {:ok, socket} = Otis.Channel.socket(context.channel)
    # the receivers get a lot of "STOP" commands as they join channels, clear
    # those out
    data_reset(mock)
    Otis.Channel.Socket.send(socket, 1234, <<"something">>)
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

  test "allows you to query the play pause state", %{channel: channel} do
    {:ok, state} = Otis.Channel.state(channel)
    assert state == :stop
  end

  test "allows you to toggle the play pause state", %{channel: channel} do

    {:ok, state} = Otis.Channel.play_pause(channel)
    assert state == :play
    {:ok, state} = Otis.Channel.play_pause(channel)
    assert state == :stop
  end

  test "broadcasts an event when a receiver is added", %{channel: channel, receiver: receiver} = context do
    :ok = Otis.Channel.add_receiver(channel, receiver)
    event = {:receiver_added, context.channel_id, receiver.id}
    assert_receive ^event
  end

  test "can have its volume set", context do
    Enum.each [context.channel, %Otis.Channel{pid: context.channel, id: context.channel_id}], fn(channel) ->
      {:ok, 1.0} = Otis.Channel.volume(channel)
      Otis.Channel.volume(channel, 0.5)
      {:ok, 0.5} = Otis.Channel.volume(channel)
      Otis.Channel.volume(channel, 1.5)
      {:ok, 1.0} = Otis.Channel.volume(channel)
      Otis.Channel.volume(channel, -1.5)
      {:ok, 0.0} = Otis.Channel.volume(channel)
      Otis.Channel.volume(channel, 1.0)
    end
  end

  test "broadcasts an event when the volume is changed", context do
    {:ok, 1.0} = Otis.Channel.volume(context.channel)
    Otis.Channel.volume(context.channel, 0.5)
    {:ok, 0.5} = Otis.Channel.volume(context.channel)
    event = {:channel_volume_change, context.channel_id, 0.5}
    assert_receive ^event
  end

  test "does not persist the receivers calculated volume", context do
    {:ok, 1.0} = Otis.Channel.volume(context.channel)
    Otis.Channel.volume(context.channel, 0.5)
    {:ok, 0.5} = Otis.Channel.volume(context.channel)
    event = {:channel_volume_change, context.channel_id, 0.5}
    assert_receive ^event
    channel = Otis.State.Channel.find context.channel_id
    assert channel.volume == 0.5
    receiver = Otis.State.Receiver.find context.receiver.id
    assert receiver.volume == 1.0
  end
end