
defmodule Otis.State.Persistence.Receivers do
  use     GenEvent
  require Logger

  alias Otis.State.Receiver
  alias Otis.State.Channel
  alias Otis.State.Repo

  def register do
    Otis.State.Events.add_mon_handler(__MODULE__, [])
  end

  def handle_event({:receiver_started, [id]}, state) do
    id |> receiver |> receiver_started(id)
    {:ok, state}
  end
  # = so we have a connection from a receiver
  # = see if we have the given id in the db
  # if yes:
  #   - find id of channel it belongs to
  # if no:
  #   - choose some default channel from the db (first when order by position..)
  # = map id to channel pid
  # = start receiver process using given id & channel etc
  #   - this should be a :create call if the receiver is new
  #   - or a :start call if the receiver existed
  # = once receiver has started it broadcasts an event which arrives back here
  #   and allows us to persist any changes
  # def handle_event({:receiver_connected, [id, channel, connection_info]}, state) do
  def handle_event({:receiver_connected, [id, recv]}, state) do
    Repo.transaction(fn ->
      id |> receiver |> receiver_connected(id, recv)
    end)
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
    Otis.State.Events.notify({:receiver_joined, [id, receiver.channel_id, receiver]})
  end

  # if neither the receiver nor the given channel are in the db, receiver at this
  # point is nil
  defp receiver_connected(:error, _id, _recv) do
  end
  defp receiver_connected(nil, id, receiver) do
    receiver_state = create_receiver(channel(), id)
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

