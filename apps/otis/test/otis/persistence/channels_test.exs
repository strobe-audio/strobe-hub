defmodule Otis.Persistence.ChannelsTest do
  use   ExUnit.Case

  alias Otis.State.Persistence

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach
    :ok
  end


  test "it persists a new channel" do
    assert Otis.State.Channel.all == []
    id = Otis.uuid
    name = "A new channel"
    {:ok, _channel} = Otis.Channels.create(id, name)
    assert_receive {:channel, :add, [^id, %{name: ^name}]}
    assert_receive {:__complete__, {:channel, :add, [^id, %{name: ^name}]}, Persistence.Channels}
    channels = Otis.State.Channel.all
    assert length(channels) == 1
    [%Otis.State.Channel{id: ^id, name: ^name}] = channels
  end

  test "it deletes a record when a channel is removed" do
    assert Otis.State.Channel.all == []
    id = Otis.uuid
    name = "A new channel"
    {:ok, _channel} = Otis.Channels.create(id, name)
    assert_receive {:channel, :add, [^id, %{name: ^name}]}, 200

    :ok = Otis.Channels.destroy!(id)
    assert_receive {:channel, :remove, [^id]}
    assert_receive {:__complete__, {:channel, :remove, [^id]}, Persistence.Channels}

    channels = Otis.State.Channel.all
    assert length(channels) == 0
  end

  test "doesn't persist an existing channel" do
    assert Otis.State.Channel.all == []
    id = Otis.uuid
    name = "A new channel"
    {:ok, channel} = Otis.Channels.create(id, name)
    pid = GenServer.whereis(channel)
    assert is_pid(pid)
    Process.monitor(pid)
    assert_receive {:channel, :add, [^id, %{name: ^name}]}, 200


    Otis.Channels.stop(channel)
    assert_receive {:DOWN, _, :process, ^pid, :shutdown}
    assert nil == GenServer.whereis(channel)

    {:ok, _channel} = Otis.Channels.create(id, name)

    channels = Otis.State.Channel.all
    assert length(channels) == 1
    [%Otis.State.Channel{id: ^id, name: ^name}] = channels
  end

  test "initializes a channel with the persisted volume", _context do
    id = Otis.uuid
    channel = Otis.State.Channel.create!(id, "Donal")
    Otis.State.Channel.volume(channel, 0.11)
    channel = Otis.State.Channel.find(id)
    assert channel.volume == 0.11

    {:ok, pid} = Otis.Channels.start(channel)

    {:ok, 0.11} = Otis.Channel.volume(pid)
  end

  test "persists volume changes" do
    assert Otis.State.Channel.all == []
    id = Otis.uuid
    name = "A new channel"
    {:ok, channel} = Otis.Channels.create(id, name)
    assert_receive {:channel, :add, [^id, %{name: ^name}]}, 200

    Otis.Channel.volume(channel, 0.33)
    assert_receive {:channel, :volume, [^id, 0.33]}
    assert_receive {:__complete__, {:channel, :volume, [^id, 0.33]}, Persistence.Channels}

    channel = Otis.State.Channel.find(id)

    assert channel.volume == 0.33
  end

  test "persists name changes", _context do
    id = Otis.uuid
    name = "A new channel"
    {:ok, _channel} = Otis.Channels.create(id, name)
    assert_receive {:channel, :add, [^id, %{name: ^name}]}, 200
    Otis.Channels.rename(id, "Believe in whales")
    assert_receive {:channel, :rename, [^id, "Believe in whales"]}
    assert_receive {:__complete__, {:channel, :rename, [^id, "Believe in whales"]}, Persistence.Channels}

    channel = Otis.State.Channel.find(id)

    assert channel.name == "Believe in whales"
  end
end
