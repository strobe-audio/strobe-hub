defmodule ChannelsTest do
  use ExUnit.Case, async: false

  alias Otis.State.Channel
  alias Otis.Test.TestSource

  @moduletag :channels

  def channel_ids() do
    Enum.map(Otis.Channels.list!(), fn pid ->
      {:ok, id} = Otis.Channel.id(pid)
      id
    end)
  end

  def shutdown do
    Otis.Channels.ids() |> Enum.each(&Otis.Channels.stop/1)
    # :ok = Otis.State.Repo.Writer.__sync__()
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Otis.State.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Otis.State.Repo, {:shared, self()})
    MessagingHandler.attach()
    shutdown()
    on_exit(&shutdown/0)
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

  test "playing status" do
    id = Otis.uuid()
    {:ok, channel} = Otis.Channels.create(id, "Something")

    assert_receive {:__complete__, {:channel, :add, [^id, _]}, Otis.State.Persistence.Channels},
                   1_500

    Otis.Channel.append(channel, [TestSource.new()])
    assert_receive {:__complete__, {:playlist, :append, [_, _]}, Otis.State.Persistence.Playlist}
    {:ok, :play} = Otis.Channel.play_pause(channel)
    assert Otis.Channels.playing?(id)
  end
end
