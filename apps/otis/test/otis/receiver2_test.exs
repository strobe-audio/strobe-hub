defmodule Otis.Receiver2Test do
  use ExUnit.Case

  alias Otis.ReceiverSocket, as: RS
  alias Otis.Receiver2, as: Receiver
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
    data_connect(id, 1234)
    socket = ctrl_connect(id)
    assert_receive {:receiver_connected, ^id, _}
    {:ok, receiver} = RS.receiver(id)
    Receiver.volume receiver, 0.13
    msg = case :gen_tcp.recv(socket, 0, 200) do
      {:ok, data} -> Poison.decode! data
      error ->
        flunk "Failed to read from socket #{ inspect error }"
    end
    assert msg == %{ "volume" => 0.13 }
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
