defmodule Elvis.Events.Broadcast do
  @moduledoc """
  This event handler is responsible for broadcasting the required events to the
  controllers in the necessary format.
  """

  use     GenStage
  require Logger

  # Send progress updates every @progress_interval times
  @progress_interval 5 # * 100 ms intervals

  def start_link do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:consumer, %{progress_count: %{}}, subscribe_to: Otis.Library.Events.producer}
  end

  def handle_events([], _from,state) do
    {:noreply, [], state}
  end
  def handle_events([event|events], from, state) do
    {:ok, state} = handle_event(event, state)
    handle_events(events, from, state)
  end

  def handle_event({:library, :response, [id, url, response, socket]}, state) do
    Phoenix.Channel.push(socket, "library-response", %{ libraryId: id, url: url, folder: response })
    {:ok, state}
  end

  def handle_event({:channel, :add, [_id, channel]}, state) do
    broadcast!("channel-add", Otis.State.status(channel))
    {:ok, state}
  end

  def handle_event({:channel, :remove, [id]}, state) do
    broadcast!("channel-remove", %{id: id})
    {:ok, state}
  end


  def handle_event({:playlist, :append, _}, state) do
    {:ok, state}
  end

  def handle_event({:rendition, :create, [rendition]}, state) do
    rendition = Otis.State.rendition(rendition, nil)
    broadcast!("rendition-create", rendition)
    {:ok, state}
  end

  def handle_event({:rendition, :active, [channel_id, rendition_id]}, state) do
    broadcast!("rendition-active", %{channelId: channel_id, renditionId: rendition_id})
    {:ok, state}
  end

  def handle_event({:channel, :rename, [channel_id, name]}, state) do
    broadcast!("channel-rename", %{channelId: channel_id, name: name})
    {:ok, state}
  end

  def handle_event({:playlist, :skip, [channel_id, skip_id, rendition_ids]}, state) do
    broadcast!("playlist-change", %{channelId: channel_id, removeRenditionIds: rendition_ids, activateRenditionId: skip_id})
    {:ok, state}
  end

  def handle_event({:playlist, :advance, [channel_id, nil, new_rendition_id]}, state) do
    broadcast!("playlist-change", %{channelId: channel_id, removeRenditionIds: [], activateRenditionId: new_rendition_id})
    {:ok, state}
  end
  def handle_event({:playlist, :advance, [channel_id, old_rendition_id, new_rendition_id]}, state) do
    broadcast!("playlist-change", %{channelId: channel_id, removeRenditionIds: [old_rendition_id], activateRenditionId: new_rendition_id})
    {:ok, state}
  end

  def handle_event({:rendition, :progress, [_channel_id, _rendition_id, _progress_ms, :infinity]}, state) do
    {:ok, state}
  end
  def handle_event({:rendition, :progress, [channel_id, rendition_id, progress_ms, duration_ms]}, state) do
    count = case Map.get(state.progress_count, channel_id, 0) do
      0 ->
        broadcast!("rendition-progress", %{
          channelId: channel_id, renditionId: rendition_id,
          progress: progress_ms, duration: duration_ms
        })
        @progress_interval
      n ->
        n - 1
    end
    {:ok, %{state | progress_count: Map.put(state.progress_count, channel_id, count)}}
  end

  def handle_event({:rendition, :delete, [rendition_id, channel_id]}, state) do
    broadcast!("playlist-change", %{channelId: channel_id, removeRenditionIds: [rendition_id], activateRenditionId: nil})
    {:ok, state}
  end

  def handle_event({:channel, :play_pause, [channel_id, status]}, state) do
    broadcast!("channel-play_pause", %{channelId: channel_id, status: status})
    {:ok, state}
  end

  def handle_event({:receiver, :online, [receiver_id, _receiver]}, state) do
    receiver_state = Otis.State.Receiver.find(receiver_id)
    broadcast!("receiver-online", Otis.State.status(receiver_state))
    {:ok, state}
  end

  def handle_event({:receiver, event, [channel_id, receiver_id]}, state)
  when event in [:add, :remove] do
    broadcast!("receiver-#{event}", %{channelId: channel_id, receiverId: receiver_id})
    {:ok, state}
  end

  def handle_event({:receiver, :reattach, [receiver_id, channel_id, _receiver]}, state) do
    broadcast!("receiver-reattach", %{channelId: channel_id, receiverId: receiver_id})
    {:ok, state}
  end

  def handle_event({:receiver, :volume, [id, volume]}, state) do
    broadcast!("volume-change", %{ id: id, target: "receiver", volume: volume })
    {:ok, state}
  end

  def handle_event({:receiver, :rename, [receiver_id, name]}, state) do
    broadcast!("receiver-rename", %{receiverId: receiver_id, name: name})
    {:ok, state}
  end

  def handle_event({:receiver, :mute, [receiver_id, muted]}, state) do
    broadcast!("receiver-mute", %{receiverId: receiver_id, muted: muted})
    {:ok, state}
  end

  def handle_event({:channel, :volume, [id, volume]}, state) do
    broadcast!("volume-change", %{ id: id, target: "channel", volume: volume })
    {:ok, state}
  end

  def handle_event({:settings, :application, [app, settings, socket]}, state) do
    Phoenix.Channel.push(socket, "settings-application", %{application: app, settings: settings})
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  defp broadcast!(event, msg) do
    Elvis.Endpoint.broadcast!("controllers:browser", event, msg)
  end
end
