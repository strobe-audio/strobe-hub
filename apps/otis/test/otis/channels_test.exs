defmodule ChannelsTest do
  use ExUnit.Case

  @moduletag :channels

  def channel_ids(channels) do
    Enum.map(Otis.Channels.list!(channels), fn(pid) -> {:ok, id} = Otis.Channel.id(pid); id end)
  end

  setup do
    MessagingHandler.attach
    {:ok, channels} = Otis.Channels.start_link(:test_channels)
    {:ok, channels: channels}
  end

  test "allows for the adding of a channel", %{channels: channels} do
    id = Otis.uuid
    {:ok, channel} = Otis.Channels.create(channels, id, "Downstairs")
    {:ok, list } = Otis.Channels.list(channels)
    assert list == [channel]
  end

  test "lets you retrieve a channel by id", %{channels: channels} do
    id = Otis.uuid
    {:ok, channel} = Otis.Channels.create(channels, id, "Downstairs")
    {:ok, found } = Otis.Channels.find(channels, id)
    assert found == channel
  end

  test "returns :error if given an invalid id", %{channels: channels} do
    result = Otis.Channels.find(channels, "channel-2")
    assert result == :error
  end

  test "starts and adds the given channel", %{channels: channels} do
    id = Otis.uuid
    {:ok, channel} = Otis.Channels.create(channels, id, "A Channel")
    {:ok, list} = Otis.Channels.list(channels)
    assert list == [channel]
  end

  test "broadcasts an event when a channel is added", %{channels: channels} do
    id = Otis.uuid
    {:ok, _channel} = Otis.Channels.create(channels, id, "My New Channel")
    assert_receive {:channel_added, ^id, %{id: ^id, name: "My New Channel"}}, 200
  end

  test "broadcasts an event when a channel is removed", %{channels: channels} do
    id = Otis.uuid
    {:ok, channel} = Otis.Channels.create(channels, id, "My New Channel")
    assert_receive {:channel_added, ^id, %{id: ^id, name: "My New Channel"}}, 200

    Otis.Channels.destroy!(channels, id)
    assert_receive {:channel_removed, ^id}, 200
    assert Process.alive?(channel) == false
  end

  test "doesn't broadcast an event when starting a channel", %{channels: channels} do
    id = Otis.uuid
    {:ok, _channel} = Otis.Channels.start(channels, id, %{name: "Something"})
    refute_receive {:channel_added, ^id, _}

    assert channel_ids(channels) == [id]
  end
end
