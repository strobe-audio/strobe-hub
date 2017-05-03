
defmodule Otis.State.Persistence.Receivers do
  use     GenStage
  require Logger

  alias Otis.State.Receiver
  alias Otis.State.Channel
  alias Otis.State.Repo

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, [], subscribe_to: Otis.Events.producer}
  end

  def handle_events([], _from, state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:receiver_started, [id]}, state) do
    id |> receiver |> receiver_started(id)
    {:ok, state}
  end

  def handle_event({:receiver_connected, [id, recv]}, state) do
    id |> receiver |> receiver_connected(id, recv)
    {:ok, state}
  end
  def handle_event({:receiver_volume_change, [id, volume]}, state) do
    Repo.transaction(fn ->
      id |> receiver |> volume_change(id, volume)
    end)
    {:ok, state}
  end
  def handle_event({:reattach_receiver, [id, channel_id, receiver]}, state) do
    Repo.transaction(fn ->
      id |> receiver |> channel_change(id, channel_id)
    end)
    # Now we've set up the receiver to join the given channel, release it from
    # whatever channels/sockets it currently belongs to and allow Receivers to
    # re-latch it and send it through the :receiver_connected mechanism
    Otis.Receiver.release_latch(receiver)
    {:ok, state}
  end
  def handle_event({:receiver_rename, [id, name]}, state) do
    Repo.transaction fn ->
      id |> receiver |> rename(id, name)
    end
    {:ok, state}
  end
  def handle_event({:receiver_muted, [id, muted]}, state) do
    Repo.transaction fn ->
      id |> receiver |> muted(id, muted)
    end
    {:ok, state}
  end
  def handle_event(_evt, state) do
    {:ok, state}
  end

  defp receiver(id) do
    Receiver.find(id, preload: :channel)
  end

  defp receiver_started(nil, _id) do
    # Can happen in tests
  end
  defp receiver_started(receiver, id) do
    Otis.Events.notify({:receiver_joined, [id, receiver.channel_id, receiver]})
  end

  # if neither the receiver nor the given channel are in the db, receiver at this
  # point is nil
  defp receiver_connected(:error, _id, _recv) do
  end
  defp receiver_connected(nil, id, receiver) do
    {:ok, receiver_state} = Repo.transaction(fn ->
      create_receiver(channel(), id)
    end)
    receiver_connected(receiver_state, id, receiver)
  end
  defp receiver_connected(receiver_state, _id, receiver) do
    channel = channel(receiver_state)
    Otis.Receiver.configure_and_join_channel(receiver, receiver_state, channel)
  end

  defp volume_change(nil, id, _volume) do
    Logger.warn "Volume change for unknown receiver #{ id }"
  end
  defp volume_change(receiver, _id, volume) do
    Receiver.volume(receiver, volume)
  end

  defp channel_change(nil, id, channel_id) do
    Logger.warn "Channel change for unknown receiver #{ id } -> channel #{ channel_id }"
  end
  defp channel_change(receiver, _id, channel_id) do
    Receiver.channel(receiver, channel_id)
  end

  defp rename(nil, id, _name) do
    Logger.warn "Rename of unknown receiver #{ id }"
  end
  defp rename(receiver, _id, name) do
    Receiver.rename(receiver, name)
  end

  defp muted(nil, id, _muted) do
    Logger.warn "Muting of unknown receiver #{id}"
  end
  defp muted(receiver, id, muted) do
    Receiver.mute(receiver, muted) |> after_muting(id, muted)
  end

  defp after_muting(receiver_state, id, false) do
    channel = channel(receiver_state)
    {:ok, receiver}  = Otis.Receivers.receiver(id)
    Otis.Receivers.Channels.buffer_receiver(receiver, channel)
    receiver_state
  end
  defp after_muting(receiver_state, _id, _state) do
    receiver_state
  end

  defp create_receiver(nil, id) do
    Logger.warn "Attempt to create receiver #{id} with a nil channel"
    :error
  end
  defp create_receiver(channel, id) do
    Receiver.create!(channel, id: id, name: invented_name(id))
  end

  defp channel do
    Channel.default_for_receiver
  end
  defp channel(receiver) do
    receiver.channel
  end

  defp invented_name(id) do
    "Receiver #{String.slice(id, 0..12)}"
  end
end

