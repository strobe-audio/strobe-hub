defmodule Elvis.Events.Broadcast do
  @moduledoc """
  This event handler is responsible for broadcasting the required events to the
  controllers in the necessary format.
  """

  use     GenEvent
  require Logger

  # Send progress updates every @progress_interval times
  @progress_interval 5 # * 100 ms intervals

  if Code.ensure_loaded?(Otis.State.Events) do
    def register do
      Otis.State.Events.add_mon_handler(__MODULE__, %{ progress_count: %{} })
    end
  else
    def register do
      :ok
    end
  end

  def handle_event({:library_request, _}, state) do
    {:ok, state}
  end

  def handle_event({:library_response, [id, response, socket]}, state) do
    Phoenix.Channel.push(socket, "library", %{ libraryId: id, folder: response })
    {:ok, state}
  end

  def handle_event({:channel_added, [_id, channel]}, state) do
    broadcast!("channel_added", Otis.State.status(channel))
    {:ok, state}
  end

  def handle_event({:new_renditions, _}, state) do
    {:ok, state}
  end

  def handle_event({:new_rendition_created, [rendition]}, state) do
    rendition = Otis.State.rendition(rendition)
    broadcast!("new_rendition_created", rendition)
    {:ok, state}
  end

  def handle_event({:channel_finished, [channel_id]}, state) do
    broadcast!("channel_play_pause", %{channelId: channel_id, status: :stop})
    {:ok, state}
  end

  def handle_event({:channel_rename, [channel_id, name]}, state) do
    broadcast!("channel_rename", %{channelId: channel_id, name: name})
    {:ok, state}
  end

  def handle_event({:renditions_skipped, [channel_id, rendition_ids]}, state) do
    broadcast!("rendition_changed", %{channelId: channel_id, removeRenditionIds: rendition_ids})
    {:ok, state}
  end

  def handle_event({:rendition_changed, [_channel_id, nil, _new_rendition_id]}, state) do
    {:ok, state}
  end
  def handle_event({:rendition_changed, [channel_id, old_rendition_id, _new_rendition_id]}, state) do
    broadcast!("rendition_changed", %{channelId: channel_id, removeRenditionIds: [old_rendition_id]})
    {:ok, state}
  end

  def handle_event({:rendition_progress, [_channel_id, _rendition_id, _progress_ms, :infinity]}, state) do
    {:ok, state}
  end
  def handle_event({:rendition_progress, [channel_id, rendition_id, progress_ms, duration_ms]}, state) do
    count = case Map.get(state.progress_count, channel_id, 0) do
      0 ->
        broadcast!("rendition_progress", %{
          channelId: channel_id, renditionId: rendition_id,
          progress: progress_ms, duration: duration_ms
        })
        @progress_interval
      n ->
        n - 1
    end
    {:ok, %{state | progress_count: Map.put(state.progress_count, channel_id, count)}}
  end

  def handle_event({:rendition_deleted, [rendition_id, channel_id]}, state) do
    broadcast!("rendition_changed", %{channelId: channel_id, removeRenditionIds: [rendition_id]})
    {:ok, state}
  end

  def handle_event({:channel_play_pause, [channel_id, status]}, state) do
    broadcast!("channel_play_pause", %{channelId: channel_id, status: status})
    {:ok, state}
  end

  def handle_event({:receiver_connected, [receiver_id, _receiver]}, state) do
    receiver_state = Otis.State.Receiver.find(receiver_id)
    broadcast!(to_string(:receiver_connected), Otis.State.status(receiver_state))
    {:ok, state}
  end

  def handle_event({event, [channel_id, receiver_id]}, state)
  when event in [:receiver_added, :receiver_removed] do
    broadcast!(to_string(event), %{channelId: channel_id, receiverId: receiver_id})
    {:ok, state}
  end

  def handle_event({:reattach_receiver, [receiver_id, channel_id, _receiver]}, state) do
    broadcast!("reattach_receiver", %{channelId: channel_id, receiverId: receiver_id})
    {:ok, state}
  end

  def handle_event({:receiver_volume_change, [id, volume]}, state) do
    broadcast!("volume_change", %{ id: id, target: "receiver", volume: volume })
    {:ok, state}
  end

  def handle_event({:receiver_rename, [receiver_id, name]}, state) do
    broadcast!("receiver_rename", %{receiverId: receiver_id, name: name})
    {:ok, state}
  end

  def handle_event({:channel_volume_change, [id, volume]}, state) do
    broadcast!("volume_change", %{ id: id, target: "channel", volume: volume })
    {:ok, state}
  end

  def handle_event(event, state) do
    IO.inspect [:broadcast?, event]
    {:ok, state}
  end

  defp broadcast!(event, msg) do
    # msg = Map.put(args, :event, event)
    Elvis.Endpoint.broadcast!("controllers:browser", event, msg)
  end
end
