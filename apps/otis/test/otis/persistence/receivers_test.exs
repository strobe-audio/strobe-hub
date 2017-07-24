defmodule Otis.Persistence.ReceiversTest do
  use    ExUnit.Case
  alias  Otis.Receivers
  alias  Otis.State.Persistence
  import MockReceiver

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach
    id = Otis.uuid
    {:ok, channel} = Otis.Channels.create(id, "Fishy")
    assert_receive {:__complete__, {:channel, :add, [^id, _]}, Persistence.Channels}
    channel = %Otis.Channel{pid: channel, id: id}
    channel_volume = 0.56
    Otis.Channel.volume channel, channel_volume
    assert_receive {:__complete__, {:channel, :volume, [^id, _]}, Persistence.Channels}
    {:ok, channel_id: id, channel: channel, channel_volume: channel_volume}
  end

  test "receivers get their volume set from the db", context do
    id = Otis.uuid
    channel = Otis.State.Channel.find(context.channel_id)
    _record = Otis.State.Receiver.create!(channel, id: id, name: "Receiver", volume: 0.34)
    mock = connect!(id, 1234)
    assert_receive {:receiver, :connect, [^id, _]}
    {:ok, msg} = ctrl_recv(mock)
    assert msg == %{ "volume" => Otis.Receiver.perceptual_volume(0.34 * context.channel_volume) }
  end

  test "receiver volume changes get persisted to the db", context do
    id = Otis.uuid
    channel = Otis.State.Channel.find(context.channel_id)
    _record = Otis.State.Receiver.create!(channel, id: id, name: "Receiver", volume: 0.34)
    _mock = connect!(id, 1234)
    assert_receive {:receiver, :connect, [^id, _]}
    assert_receive {:receiver, :online, [^id, _]}
    assert_receive {:__complete__, {:receiver, :volume, [^id, 0.34]}, Persistence.Receivers}
    Otis.Events.notify(:receiver, :volume, [id, 0.98])
    assert_receive {:receiver, :volume, [^id, 0.98]}
    assert_receive {:__complete__, {:receiver, :volume, [^id, 0.98]}, Persistence.Receivers}
    record = Otis.State.Receiver.find id
    assert record.volume == 0.98
  end

  test "receivers get attached to the assigned channel", context do
    id = Otis.uuid
    channel = Otis.State.Channel.find(context.channel_id)
    _record = Otis.State.Receiver.create!(channel, id: id, name: "Receiver", volume: 0.34)
    _mock = connect!(id, 1234)
    assert_receive {:receiver, :connect, [^id, _]}
    assert_receive {:receiver, :online, [^id, _]}
    {:ok, receiver} = Receivers.receiver(id)
    receivers = Otis.Receivers.Channels.lookup(context.channel.id)
    assert receivers == [receiver]
  end

  test "receiver channel changes get persisted", context do
    id = Otis.uuid
    channel = Otis.State.Channel.find(context.channel_id)
    _record = Otis.State.Receiver.create!(channel, id: id, name: "Receiver", volume: 0.34)
    _mock = connect!(id, 1234)
    assert_receive {:receiver, :connect, [^id, _]}
    assert_receive {:receiver, :online, [^id, _]}
    {:ok, receiver} = Receivers.receiver(id)
    receivers = Otis.Receivers.Channels.lookup(context.channel.id)
    assert receivers == [receiver]

    channel1_id = context.channel.id
    channel2_id = Otis.uuid()
    {:ok, _channel2} = Otis.Channels.create(channel2_id, "Froggy")
    assert_receive {:__complete__, {:channel, :add, [^channel2_id, _]}, Persistence.Channels}

    Otis.Receivers.attach id, channel2_id
    assert_receive {:receiver, :remove, [^channel1_id, ^id]}
    assert_receive {:receiver, :add, [^channel2_id, ^id]}
    assert_receive {:receiver, :online, [^id, _]}
    record = Otis.State.Receiver.find id
    assert record.channel_id == channel2_id
    {:ok, receiver} = Receivers.receiver(id)
    receivers = Otis.Receivers.Channels.lookup(context.channel.id)
    assert receivers == []
    receivers = Otis.Receivers.Channels.lookup(channel2_id)
    assert receivers == [receiver]
  end

  test "receiver mute state gets persisted to the db", context do
    id = Otis.uuid
    channel = Otis.State.Channel.find(context.channel_id)
    _record = Otis.State.Receiver.create!(channel, id: id, name: "Receiver", volume: 0.34, muted: false)
    _mock = connect!(id, 1234)
    assert_receive {:receiver, :connect, [^id, _]}
    assert_receive {:receiver, :online, [^id, _]}
    Otis.Events.notify(:receiver, :mute, [id, true])
    assert_receive {:receiver, :mute, [^id, true]}
    assert_receive {:__complete__, {:receiver, :mute, [^id, true]}, Persistence.Receivers}
    record = Otis.State.Receiver.find id
    assert record.muted == true
  end
end
