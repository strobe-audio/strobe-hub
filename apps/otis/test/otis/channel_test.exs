defmodule Otis.ChannelTest do
  use    ExUnit.Case

  import MockReceiver

  alias Otis.Receivers
  alias Otis.Test.TestSource
  alias Otis.State.Persistence

  @moduletag :channel

  def playlist(context, sources) do
    {:ok, pl} = Otis.Channel.playlist(context.channel)
    :ok = Otis.Pipeline.Playlist.append(pl, sources)
    assert_receive {:__complete__, {:playlist, :append, _}, Persistence.Playlist}
    {:ok, pl}
  end

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Otis.State.Repo)
    MessagingHandler.attach()
    Otis.State.Receiver.delete_all()
    Otis.State.Channel.delete_all()
    channel_id = Otis.uuid()
    receiver_id = Otis.uuid()

    config = %Otis.Pipeline.Config{ Otis.Pipeline.Config.new(20) |
      clock: {Test.Otis.Pipeline.Clock, :start_link, [self(), 1_000_000]},
    }
    {:ok, channel} = Otis.Channels.create(channel_id, "Something", config)
    assert_receive {:__complete__, {:channel, :add, [^channel_id, _]}, Persistence.Channels}
    channel_record = Otis.State.Channel.find(channel_id)
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: receiver_id, name: "Roger", volume: 1.0)
    mock = connect!(receiver_id, 1234)
    assert_receive {:__complete__, {:receiver, :connect, [^receiver_id, _]}, Persistence.Receivers}
    {:ok, receiver} = Receivers.receiver(receiver_id)

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

  test "allows you to query the play pause state", %{channel: channel} do
    {:ok, state} = Otis.Channel.state(channel)
    assert state == :pause
  end

  test "allows you to toggle the play pause state", %{channel: channel} = context do
    channel_id = context.channel_id
    {:ok, _pl} = playlist(context, TestSource.new)
    {:ok, state} = Otis.Channel.play_pause(channel)
    assert state == :play
    assert_receive {:__complete__, {:channel, :play_pause, [^channel_id, :play]}, _}
    assert_receive {:clock, {:start, _bc, _time}}, 500
    {:ok, state} = Otis.Channel.play_pause(channel)
    assert state == :pause
    assert_receive {:__complete__, {:channel, :play_pause, [^channel_id, :pause]}, _}
    assert_receive {:clock, {:stop}}, 500
    {:ok, state} = Otis.Channel.play_pause(channel)
    assert state == :play
    assert_receive {:__complete__, {:channel, :play_pause, [^channel_id, :play]}, _}
    assert_receive {:clock, {:start, _bc, _time}}, 500
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
    event = {:channel, :volume, [context.channel_id, 0.5]}
    assert_receive ^event
  end

  test "does not persist the receivers calculated volume", context do
    {:ok, 1.0} = Otis.Channel.volume(context.channel)
    Otis.Channel.volume(context.channel, 0.5)
    {:ok, 0.5} = Otis.Channel.volume(context.channel)
    event = {:channel, :volume, [context.channel_id, 0.5]}
    assert_receive ^event
    assert_receive {:__complete__, ^event, Persistence.Channels}
    channel = Otis.State.Channel.find context.channel_id
    assert channel.volume == 0.5
    receiver = Otis.State.Receiver.find context.receiver.id
    assert receiver.volume == 1.0
  end

  test "broadcasting event when play state changes", context do
    # Need to add something to the playlist or the channel stops as soon as it starts
    {:ok, _pl} = playlist(context, TestSource.new)
    channel_id = context.channel_id
    {:ok, :play} = Otis.Channel.play_pause(context.channel)
    assert_receive {:channel, :play_pause, [^channel_id, :play]}
    {:ok, :pause} = Otis.Channel.play_pause(context.channel)
    assert_receive {:channel, :play_pause, [^channel_id, :pause]}
  end

  test "playlist end broadcasts event", context do
    channel_id = context.channel_id
    {:ok, :play} = Otis.Channel.play_pause(context.channel)
    assert_receive {:channel, :play_pause, [^channel_id, :play]}
    assert_receive {:channel, :play_pause, [^channel_id, :pause]}
  end

  @tag :skip
  test "skipping renditions"

  test "removing renditions", %{channel_id: channel_id} = context do
    {:ok, pl} = playlist(context, TestSource.new)
    {:ok, [rendition_id]} = Otis.Pipeline.Playlist.list(pl)
    :ok = Otis.Channel.remove(context.channel, rendition_id)
    assert_receive {:rendition, :delete, [^rendition_id, ^channel_id]}
  end

  test "playback completion sets state & sends message", context do
    channel_id = context.channel_id
    {:ok, :play} = Otis.Channel.play_pause(context.channel)
    assert_receive {:channel, :play_pause, [^channel_id, :play]}
    pid = GenServer.whereis(context.channel)
    send pid, :broadcaster_stop
    assert_receive {:channel, :play_pause, [^channel_id, :pause]}
  end

  test "clearing playlist", context do
    channel_id = context.channel_id
    {:ok, pl} = playlist(context, TestSource.new)
    {:ok, [rendition_id]} = Otis.Pipeline.Playlist.list(pl)
    :ok = Otis.Channel.clear(context.channel)
    assert_receive {:__complete__, {:playlist, :clear, [^channel_id, _]}, Persistence.Playlist}
    assert_receive {:rendition, :delete, [^rendition_id, ^channel_id]}
  end

  test "appending sources via events", %{channel_id: channel_id} = context do
    sources = [TestSource.new, TestSource.new]
    Strobe.Events.notify(:library, :play, [channel_id, sources])
    evt = {:library, :play, [channel_id, sources]}
    assert_receive {:__complete__, ^evt, Otis.State.Library}
    {:ok, pl} = Otis.Channel.playlist(context.channel)
    {:ok, ids} = Otis.Pipeline.Playlist.list(pl)
    assert length(ids) == 2
    assert_receive {:__complete__, {:playlist, :append, [_, _]}, Persistence.Playlist}
  end
end