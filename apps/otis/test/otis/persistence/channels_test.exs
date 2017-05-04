defmodule Otis.Persistence.ChannelsTest do
  use   ExUnit.Case

  setup_all do
    on_exit fn ->
      Otis.State.Channel.delete_all
    end
    :ok
  end

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
    assert_receive {:channel_added, [^id, %{name: ^name}]}, 200
    channels = Otis.State.Channel.all
    assert length(channels) == 1
    [%Otis.State.Channel{id: ^id, name: ^name}] = channels
  end

  test "it deletes a record when a channel is removed" do
    assert Otis.State.Channel.all == []
    id = Otis.uuid
    name = "A new channel"
    {:ok, _channel} = Otis.Channels.create(id, name)
    assert_receive {:channel_added, [^id, %{name: ^name}]}, 200

    :ok = Otis.Channels.destroy!(id)
    assert_receive {:channel_removed, [^id]}
    assert_receive {:"$__channel_remove", [^id]}

    channels = Otis.State.Channel.all
    assert length(channels) == 0
  end

  test "doesn't persist an existing channel" do
    assert Otis.State.Channel.all == []
    id = Otis.uuid
    name = "A new channel"
    {:ok, channel} = Otis.Channels.create(id, name)
    assert_receive {:channel_added, [^id, %{name: ^name}]}, 200


    Otis.Channels.stop(channel)
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
    assert_receive {:channel_added, [^id, %{name: ^name}]}, 200

    Otis.Channel.volume(channel, 0.33)
    assert_receive {:channel_volume_change, [^id, 0.33]}
    assert_receive {:"$__channel_volume_change", [^id]}

    channel = Otis.State.Channel.find(id)

    assert channel.volume == 0.33
  end

  test "persists name changes", _context do
    id = Otis.uuid
    name = "A new channel"
    {:ok, _channel} = Otis.Channels.create(id, name)
    assert_receive {:channel_added, [^id, %{name: ^name}]}, 200
    Otis.Channels.rename(id, "Believe in whales")
    assert_receive {:channel_rename, [^id, "Believe in whales"]}
    assert_receive {:"$__channel_rename", [^id]}

    channel = Otis.State.Channel.find(id)

    assert channel.name == "Believe in whales"
  end
end
