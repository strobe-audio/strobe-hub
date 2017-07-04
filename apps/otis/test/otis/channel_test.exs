defmodule Otis.ChannelTest do
  use    ExUnit.Case

  import MockReceiver

  alias Otis.Receivers
  alias Otis.Test.TestSource

  @moduletag :channel

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
    assert_receive {:"$__channel_added", [^channel_id]}
    channel_record = Otis.State.Channel.find(channel_id)
    _receiver_record = Otis.State.Receiver.create!(channel_record, id: receiver_id, name: "Roger", volume: 1.0)
    mock = connect!(receiver_id, 1234)
    assert_receive {:"$__receiver_connected", [^receiver_id]}
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
    {:ok, pl} = Otis.Channel.playlist(context.channel)
    :ok = Otis.Pipeline.Playlist.append(pl, TestSource.new)
    assert_receive {:"$__append_renditions", _}
    {:ok, state} = Otis.Channel.play_pause(channel)
    assert state == :play
    assert_receive {:channel_play_pause, [^channel_id, :play]}
    assert_receive {:clock, {:start, _bc, _time}}
    {:ok, state} = Otis.Channel.play_pause(channel)
    assert state == :pause
    assert_receive {:channel_play_pause, [^channel_id, :pause]}
    assert_receive {:clock, {:stop}}
    {:ok, state} = Otis.Channel.play_pause(channel)
    assert state == :play
    assert_receive {:channel_play_pause, [^channel_id, :play]}
    assert_receive {:clock, {:start, _bc, _time}}
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
    event = {:channel_volume_change, [context.channel_id, 0.5]}
    assert_receive ^event
  end

  test "does not persist the receivers calculated volume", context do
    {:ok, 1.0} = Otis.Channel.volume(context.channel)
    Otis.Channel.volume(context.channel, 0.5)
    {:ok, 0.5} = Otis.Channel.volume(context.channel)
    event = {:channel_volume_change, [context.channel_id, 0.5]}
    assert_receive ^event
    event = {:"$__channel_volume_change", [context.channel_id]}
    assert_receive ^event
    channel = Otis.State.Channel.find context.channel_id
    assert channel.volume == 0.5
    receiver = Otis.State.Receiver.find context.receiver.id
    assert receiver.volume == 1.0
  end

  test "broadcasting event when play state changes", context do
    # Need to add something to the playlist or the channel stops as soon as it starts
    {:ok, pl} = Otis.Channel.playlist(context.channel)
    :ok = Otis.Pipeline.Playlist.append(pl, TestSource.new)
    assert_receive {:"$__append_renditions", _}
    channel_id = context.channel_id
    {:ok, :play} = Otis.Channel.play_pause(context.channel)
    assert_receive {:channel_play_pause, [^channel_id, :play]}
    {:ok, :pause} = Otis.Channel.play_pause(context.channel)
    assert_receive {:channel_play_pause, [^channel_id, :pause]}
  end

  test "playlist end broadcasts event", context do
    channel_id = context.channel_id
    {:ok, :play} = Otis.Channel.play_pause(context.channel)
    assert_receive {:channel_play_pause, [^channel_id, :play]}
    assert_receive {:channel_play_pause, [^channel_id, :pause]}
  end

  @tag :skip
  test "skipping renditions"

  test "removing renditions", %{channel_id: channel_id} = context do
    {:ok, pl} = Otis.Channel.playlist(context.channel)
    :ok = Otis.Pipeline.Playlist.append(pl, TestSource.new)
    assert_receive {:"$__append_renditions", _}
    {:ok, [rendition_id]} = Otis.Pipeline.Playlist.list(pl)
    :ok = Otis.Channel.remove(context.channel, rendition_id)
    assert_receive {:rendition_deleted, [^rendition_id, ^channel_id]}
  end

  test "playback completion sets state & sends message", context do
    channel_id = context.channel_id
    {:ok, :play} = Otis.Channel.play_pause(context.channel)
    assert_receive {:channel_play_pause, [^channel_id, :play]}
    pid = GenServer.whereis(context.channel)
    send pid, :broadcaster_stop
    assert_receive {:channel_play_pause, [^channel_id, :pause]}
  end

  test "clearing playlist", context do
    channel_id = context.channel_id
    {:ok, pl} = Otis.Channel.playlist(context.channel)
    :ok = Otis.Pipeline.Playlist.append(pl, TestSource.new)
    assert_receive {:"$__append_renditions", _}
    {:ok, [rendition_id]} = Otis.Pipeline.Playlist.list(pl)
    :ok = Otis.Channel.clear(context.channel)
    assert_receive {:"$__playlist_cleared", [^channel_id]}
    assert_receive {:rendition_deleted, [^rendition_id, ^channel_id]}
  end
end