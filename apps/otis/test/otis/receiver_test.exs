defmodule Otis.ReceiverTest do
  use ExUnit.Case

  alias  Otis.ReceiverSocket, as: RS
  alias  Otis.Receiver, as: Receiver
  import MockReceiver

  setup do
    MessagingHandler.attach
    :ok
  end

  test "doesn't start a new receiver with just a data connection", _context do
    id = Otis.uuid
    data_connect(id, 1000)
    refute_receive {:receiver_connected, ^id, _, _}
  end

  test "doesn't start a new receiver with just a ctrl connection", _context do
    id = Otis.uuid
    ctrl_connect(id)
    refute_receive {:receiver_connected, ^id, _, _}
  end

  test "emits receiver connect event when receiver & data connect", _context do
    id = Otis.uuid
    data_connect(id, 1000)
    ctrl_connect(id)
    assert_receive {:receiver_connected, ^id, _}
  end

  test "it doesn't register receiver when data & ctrl ids differ", _context do
    data_connect(Otis.uuid, 1000)
    ctrl_connect(Otis.uuid)
    refute_receive {:receiver_connected, _, _}
  end

  test "receiver registered with correct latency", _context do
    id = Otis.uuid
    data_connect(id, 1234)
    ctrl_connect(id)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = RS.receiver(id)
    assert receiver.latency == 1234
  end

  test "setting the volume sends the right command", _context do
    id = Otis.uuid
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = RS.receiver(id)
    Receiver.volume receiver, 0.13
    assert_receive {:receiver_volume_change, ^id, 0.13}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.13 }
    {:ok, 0.13} = Receiver.volume receiver
  end

  test "setting the volume multiplier sends the right command", _context do
    id = Otis.uuid
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = RS.receiver(id)

    Receiver.volume receiver, 0.13
    assert_receive {:receiver_volume_change, ^id, 0.13}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.13 }

    Receiver.volume_multiplier receiver, 0.5
    refute_receive {:receiver_volume_change, ^id, _}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.065 }
    {:ok, 0.5} = Receiver.volume_multiplier receiver

    Receiver.volume receiver, 0.6
    assert_receive {:receiver_volume_change, ^id, 0.6}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.3 }

    Receiver.volume_multiplier receiver, 0.1
    refute_receive {:receiver_volume_change, ^id, _}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.06 }
  end

  test "setting the volume & multiplier simultaneously", _context do
    id = Otis.uuid
    mock = connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = RS.receiver(id)

    Receiver.volume receiver, 0.3, 0.1
    assert_receive {:receiver_volume_change, ^id, 0.3}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.03 }

    Receiver.volume receiver, 0.1, 0.3
    assert_receive {:receiver_volume_change, ^id, 0.1}
    # Could assert that no volume change message is sent, but really, who cares!?
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => 0.03 }

    Receiver.volume receiver, 0.9, 0.1
    assert_receive {:receiver_volume_change, ^id, 0.9}
    {:ok, %{ "volume" => volume }} = ctrl_recv(mock)
    assert_in_delta volume, 0.09, 0.0001
  end

  test "broadcasts an event on volume change" do
    id = Otis.uuid
    connect!(id, 1234)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = RS.receiver(id)
    Receiver.volume receiver, 0.13
    assert_receive {:receiver_volume_change, id, 0.13}
  end

  test "the receiver remembers its volume setting", _context do
    id = Otis.uuid
    data_connect(id, 1234)
    ctrl_connect(id)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = RS.receiver(id)
    Receiver.volume receiver, 0.13
    assert {:ok, 0.13} == Receiver.volume receiver
  end

  test "data connection error sends disconnect event", _context do
    id = Otis.uuid
    socket = data_connect(id, 2222)
    ctrl_connect(id)
    assert_receive {:receiver_connected, ^id, _}
    :ok = :gen_tcp.close(socket)
    assert_receive {:receiver_disconnected, ^id, _}, 200
    {:ok, receiver} = RS.receiver(id)
    assert receiver.id == id
  end

  test "ctrl connection error sends disconnect event", _context do
    id = Otis.uuid
    data_connect(id, 2222)
    socket = ctrl_connect(id)
    assert_receive {:receiver_connected, ^id, _}
    :ok = :gen_tcp.close(socket)
    assert_receive {:receiver_disconnected, ^id, _}, 200
    {:ok, receiver} = RS.receiver(id)
    assert receiver.id == id
  end

  test "all connection error sends disconnect and removes receiver", _context do
    id = Otis.uuid
    data_socket = data_connect(id, 2222)
    ctrl_socket = ctrl_connect(id)
    assert_receive {:receiver_connected, ^id, _}
    :ok = :gen_tcp.close(data_socket)
    assert_receive {:receiver_disconnected, ^id, _}
    :ok = :gen_tcp.close(ctrl_socket)
    assert_receive {:receiver_offline, ^id, _}
    :error = RS.receiver(id)
  end
end
