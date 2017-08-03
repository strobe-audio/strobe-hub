defmodule ChannelsTest do
  use ExUnit.Case

  alias Otis.State.Channel

  @moduletag :channels

  def channel_ids() do
    Enum.map(Otis.Channels.list!(), fn(pid) -> {:ok, id} = Otis.Channel.id(pid); id end)
  end

  def shutdown do
    Otis.Channels.ids() |> Enum.each(&Otis.Channels.destroy!/1)
  end

  setup do
    shutdown()
    MessagingHandler.attach()
    on_exit &shutdown/0
    :ok
  end

  test "allows for the adding of a channel" do
    id = Otis.uuid()
    {:ok, channel} = Otis.Channels.create(id, "Downstairs")
    pid = GenServer.whereis(channel)
    {:ok, list} = Otis.Channels.list()
    assert list == [pid]
  end

  test "lets you retrieve a channel by id" do
    id = Otis.uuid()
    {:ok, channel} = Otis.Channels.create(id, "Downstairs")
    pid = GenServer.whereis(channel)
    {:ok, found} = Otis.Channels.find(id)
    assert found == pid
  end

  test "returns :error if given an invalid id" do
    result = Otis.Channels.find("channel-2")
    assert result == :error
  end

  test "starts and adds the given channel" do
    id = Otis.uuid()
    {:ok, channel} = Otis.Channels.create(id, "A Channel")
    pid = GenServer.whereis(channel)
    {:ok, list} = Otis.Channels.list()
    assert list == [pid]
  end

  test "broadcasts an event when a channel is added" do
    id = Otis.uuid()
    {:ok, _channel} = Otis.Channels.create(id, "My New Channel")
    assert_receive {:channel, :add, [^id, %{id: ^id, name: "My New Channel"}]}, 200
  end

  test "broadcasts an event when a channel is removed" do
    id = Otis.uuid()
    {:ok, channel} = Otis.Channels.create(id, "My New Channel")
    assert_receive {:channel, :add, [^id, %{id: ^id, name: "My New Channel"}]}, 200

    Otis.Channels.destroy!(id)
    assert_receive {:channel, :remove, [^id]}, 200
    pid = GenServer.whereis(channel)
    assert pid == nil
  end

  test "doesn't broadcast an event when starting a channel" do
    id = Otis.uuid()
    {:ok, _channel} = Otis.Channels.start(%Channel{id: id, name: "Something"})
    refute_receive {:channel, :add, [^id, _]}

    assert channel_ids() == [id]
    assert Otis.Channels.ids() == [id]
  end
end
