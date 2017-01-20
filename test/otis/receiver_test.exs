defmodule Otis.ReceiverTest do
  use ExUnit.Case

  alias  Otis.Receivers
  alias  Otis.Receiver
  import MockReceiver

  setup do
    MessagingHandler.attach
    :ok
  end

  test "doesn't start a new receiver with just a data connection", _context do
    id = Otis.uuid
    data_connect(id, 1000)
    refute_receive {:receiver_connected, [^id, _, _]}
  end

  test "doesn't start a new receiver with just a ctrl connection", _context do
    id = Otis.uuid
    ctrl_connect(id)
    refute_receive {:receiver_connected, [^id, _, _]}
  end

  test "emits receiver connect event when receiver & data connect", _context do
    id = Otis.uuid
    data_connect(id, 1000)
    ctrl_connect(id)
    assert_receive {:receiver_connected, [^id, _]}
  end

  test "it doesn't register receiver when data & ctrl ids differ", _context do
    data_connect(Otis.uuid, 1000)
    ctrl_connect(Otis.uuid)
    refute_receive {:receiver_connected, [_, _]}
  end

  test "receiver registered with correct latency", _context do
    id = Otis.uuid
    data_connect(id, 1234)
    ctrl_connect(id)
    assert_receive {:receiver_connected, [^id, _]}
    {:ok, receiver} = Receivers.receiver(id)
    assert receiver.latency == 1234
  end

  test "setting the volume sends the right command", _context do
    id = Otis.uuid
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    {:ok, receiver} = Receivers.receiver(id)
    ctrl_reset(mock)
    Receiver.volume receiver, 0.13
    assert_receive {:receiver_volume_change, [^id, 0.13]}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.13 }
    {:ok, 0.13} = Receiver.volume receiver
  end

  test "setting the volume multiplier sends the right command", _context do
    id = Otis.uuid
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    {:ok, receiver} = Receivers.receiver(id)

    ctrl_reset(mock)

    Receiver.volume receiver, 0.13
    assert_receive {:receiver_volume_change, [^id, 0.13]}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.13 }

    Receiver.volume_multiplier receiver, 0.5
    refute_receive {:receiver_volume_change, [^id, 0.13]}
    refute_receive {:receiver_volume_change, [^id, 0.065]}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.065 }
    {:ok, 0.5} = Receiver.volume_multiplier receiver

    Receiver.volume receiver, 0.6
    assert_receive {:receiver_volume_change, [^id, 0.6]}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.3 }

    Receiver.volume_multiplier receiver, 0.1
    refute_receive {:receiver_volume_change, [^id, 0.6]}
    refute_receive {:receiver_volume_change, [^id, 0.06]}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.06 }
  end

  test "setting the volume & multiplier simultaneously", _context do
    id = Otis.uuid
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    {:ok, receiver} = Receivers.receiver(id)

    ctrl_reset(mock)

    Receiver.volume receiver, 0.3, 0.1
    assert_receive {:receiver_volume_change, [^id, 0.3]}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.03 }

    Receiver.volume receiver, 0.1, 0.3
    assert_receive {:receiver_volume_change, [^id, 0.1]}
    # Could assert that no volume change message is sent, but really, who cares!?
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.03 }

    Receiver.volume receiver, 0.9, 0.1
    assert_receive {:receiver_volume_change, [^id, 0.9]}
    {:ok, %{ "volume" => volume }} = ctrl_recv(mock)
    assert_in_delta volume, 0.09, 0.0001
  end

  test "broadcasts an event on volume change" do
    id = Otis.uuid
    connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    {:ok, receiver} = Receivers.receiver(id)
    Receiver.volume receiver, 0.13
    assert_receive {:receiver_volume_change, [^id, 0.13]}
  end

  test "the receiver remembers its volume setting", _context do
    id = Otis.uuid
    data_connect(id, 1234)
    ctrl_connect(id)
    assert_receive {:receiver_connected, [^id, _]}
    {:ok, receiver} = Receivers.receiver(id)
    Receiver.volume receiver, 0.13
    assert {:ok, 0.13} == Receiver.volume receiver
  end

  test "data connection error sends disconnect event", _context do
    id = Otis.uuid
    socket = data_connect(id, 2222)
    ctrl_connect(id)
    assert_receive {:receiver_connected, [^id, _]}
    :ok = :gen_tcp.close(socket)
    assert_receive {:receiver_disconnected, [^id, _]}, 200
    {:ok, receiver} = Receivers.receiver(id)
    assert receiver.id == id
  end

  test "ctrl connection error sends disconnect event", _context do
    id = Otis.uuid
    data_connect(id, 2222)
    socket = ctrl_connect(id)
    assert_receive {:receiver_connected, [^id, _]}
    :ok = :gen_tcp.close(socket)
    assert_receive {:receiver_disconnected, [^id, _]}, 200
    {:ok, receiver} = Receivers.receiver(id)
    assert receiver.id == id
  end

  test "all connection error sends disconnect and removes receiver", _context do
    id = Otis.uuid
    data_socket = data_connect(id, 2222)
    ctrl_socket = ctrl_connect(id)
    assert_receive {:receiver_connected, [^id, _]}
    :ok = :gen_tcp.close(data_socket)
    assert_receive {:receiver_disconnected, [^id, _]}
    :ok = :gen_tcp.close(ctrl_socket)
    assert_receive {:receiver_offline, [^id, _]}
    :error = Receivers.receiver(id)
  end

  test "stop sends the right data command", _context do
    id = Otis.uuid
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    {:ok, receiver} = Receivers.receiver(id)
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 1.0 }
    Receiver.stop(receiver)
    {:ok, data} = data_recv_raw(mock)
    assert data == <<"STOP">>
    # {:ok, msg} = ctrl_recv(mock)
    # assert msg == %{ "command" => "stop" }
  end

  test "receiver gets added to correct channel set", _context do
    channel_id = Otis.uuid
    id = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    receiver_record = Otis.State.Receiver.create!(channel_record, id: id)
    assert receiver_record.id == id
    assert receiver_record.channel_id == channel_id

    _mock = connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    [r] = Otis.Receivers.Channels.lookup(channel_id)
    assert r.id == id
  end

  test "offline receiver gets removed from channel set", _context do
    channel_id = Otis.uuid
    id = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id)
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    :ok = :gen_tcp.close(mock.data_socket)
    assert_receive {:receiver_disconnected, [^id, _]}
    assert [] == Otis.Receivers.Channels.lookup(channel_id)
  end

  test "subscribers receive notifications when receiver joins set", _context do
    channel_id = Otis.uuid
    id = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id)
    Otis.Receivers.Channels.subscribe(:test, channel_id)
    _mock = connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    assert_receive {:receiver_joined, [^id, _]}
  end

  test "subscribers receive notifications when receiver leaves set", _context do
    channel_id = Otis.uuid
    id = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id)
    Otis.Receivers.Channels.subscribe(:test, channel_id)
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    assert_receive {:receiver_joined, [^id, _]}
    :ok = :gen_tcp.close(mock.data_socket)
    assert_receive {:receiver_disconnected, [^id, _]}
    assert_receive {:receiver_left, [^id, _]}
  end

  test "we can send data to a receiver set", _context do
    channel_id = Otis.uuid
    id1 = Otis.uuid
    id2 = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id1)
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id2)
    mock1 = connect!(id1, 1234)
    mock2 = connect!(id2, 1234)
    assert_receive {:receiver_connected, [^id1, _]}
    assert_receive {:receiver_connected, [^id2, _]}
    Otis.Receivers.Channels.send_data(channel_id, <<"DATA">>)
    {:ok, data} = data_recv_raw(mock1)
    assert data == <<"DATA">>
    {:ok, data} = data_recv_raw(mock2)
    assert data == <<"DATA">>
  end

  test "we can send volume multiplier settings to a receiver set", _context do
    channel_id = Otis.uuid
    id1 = Otis.uuid
    id2 = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id1)
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id2)
    mock1 = connect!(id1, 1234)
    mock2 = connect!(id2, 1234)
    assert_receive {:receiver_connected, [^id1, _]}
    assert_receive {:receiver_connected, [^id2, _]}
    assert_receive {:receiver_volume_change, [^id1, 1.0]}
    assert_receive {:receiver_volume_change, [^id2, 1.0]}
    {:ok, msg} = ctrl_recv(mock1)
    assert msg == %{ "volume" => 1.0 }
    {:ok, msg} = ctrl_recv(mock2)
    assert msg == %{ "volume" => 1.0 }
    Otis.Receivers.Channels.volume_multiplier(channel_id, 0.5)
    # we don't get notifications when the multiplier changes
    refute_receive {:receiver_volume_change, [^id1, _]}
    refute_receive {:receiver_volume_change, [^id2, _]}
    {:ok, msg} = ctrl_recv(mock1)
    assert msg == %{ "volume" => 0.5 }
    {:ok, msg} = ctrl_recv(mock2)
    assert msg == %{ "volume" => 0.5 }
  end

  test "we can send stop commands to a receiver set", _context do
    channel_id = Otis.uuid
    id1 = Otis.uuid
    id2 = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id1)
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id2)
    mock1 = connect!(id1, 1234)
    mock2 = connect!(id2, 1234)
    assert_receive {:receiver_connected, [^id1, _]}
    assert_receive {:receiver_connected, [^id2, _]}
    {:ok, msg} = ctrl_recv(mock1)
    assert msg == %{ "volume" => 1.0 }
    {:ok, msg} = ctrl_recv(mock2)
    assert msg == %{ "volume" => 1.0 }
    Otis.Receivers.Channels.stop(channel_id)
    # {:ok, msg} = ctrl_recv(mock1)
    # assert msg == %{ "command" => "stop" }
    {:ok, data} = data_recv_raw(mock1)
    assert data == <<"STOP">>
    # {:ok, msg} = ctrl_recv(mock2)
    # assert msg == %{ "command" => "stop" }
    {:ok, data} = data_recv_raw(mock2)
    assert data == <<"STOP">>
  end

  test "we can get a receiver set latency", _context do
    channel_id = Otis.uuid
    id1 = Otis.uuid
    id2 = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id1)
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id2)
    _mock1 = connect!(id1, 143)
    _mock2 = connect!(id2, 124)
    assert_receive {:receiver_connected, [^id1, _]}
    assert_receive {:receiver_connected, [^id2, _]}
    assert Otis.Receivers.Channels.latency(channel_id) == 143
  end

  test "we can query the connection status of a receiver" do
    id = Otis.uuid
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, [^id, _]}
    assert true == Receivers.connected?(id)
    assert false == Receivers.connected?(Otis.uuid)
    :ok = :gen_tcp.close(mock.data_socket)
    assert_receive {:receiver_disconnected, [^id, _]}
    assert false == Receivers.connected?(id)
  end

  test "detecting error responses", _context do
    results = [
      :ok,
      :ok,
      {:error, :something},
    ]
    assert {:error, :something} == Otis.Receivers.DataConnection.return_errors(results)
    results = [
      :ok,
      :ok,
    ]
    assert :ok == Otis.Receivers.DataConnection.return_errors(results)
    results = [
      {:error, :something},
      {:error, :anotherthing},
    ]
    assert {:error, :something} == Otis.Receivers.DataConnection.return_errors(results)
  end

  test "connecting receiver with existing (presumably stale) connections", _context do
    channel_id = Otis.uuid
    id = Otis.uuid
    channel_record = Otis.State.Channel.create!(channel_id, "Something")
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: id)
    _mock1 = connect!(id, 143)
    assert_receive {:receiver_connected, [^id, _]}

    {:ok, r} = Otis.Receivers.receiver(id)
    {_, ctrl} = r.ctrl
    {_, data} = r.data
    ctrl_status = :erlang.port_info(ctrl)
    assert is_pid(ctrl_status[:connected]) == true
    data_status = :erlang.port_info(data)
    assert is_pid(data_status[:connected]) == true
    # reconnect the same receiver ...
    _mock1 = connect!(id, 143)

    refute_receive {:receiver_disconnected, [^id, _]}

    # test that the previous tcp connections have been closed
    assert :undefined == :erlang.port_info(ctrl)
    assert :undefined == :erlang.port_info(data)
    assert_receive {:receiver_connected, [^id, _]}
    # validate that our receiver db is correct
    {:ok, r} = Otis.Receivers.receiver(id)
    assert Receiver.alive?(r)
  end
end
