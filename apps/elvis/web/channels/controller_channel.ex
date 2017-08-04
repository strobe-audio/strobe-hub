defmodule Elvis.ControllerChannel do
  use Phoenix.Channel

  require Logger

  @min_volume_change_interval_ms 50

  def join("controllers:" <> controller_type, _params, socket) do
    # Don't send the socket with the event because we can't send anything until
    # the channel has been joined (which happens when this function returns)
    # TODO: can use this event to send wakeup calls to the receivers
    #
    Strobe.Events.notify(:controller, :connect, [controller_type])
    send self(), :controller_join
    socket = assign_volume_change(socket, now())
    {:ok, socket}
  end

  def handle_in("volume-change", ["receiver", locked, channel_id, id, volume], socket) do
    socket = test_volume_change_interval(socket, Otis.Receivers, [id, channel_id, volume, [lock: locked]])
    {:noreply, socket}
  end
  def handle_in("volume-change", ["channel", locked, _channel_id, id, volume], socket) do
    socket = test_volume_change_interval(socket, Otis.Channels, [id, volume, [lock: locked]])
    {:noreply, socket}
  end

  def handle_in("receiver-mute", [id, muted], socket) do
    Otis.Receivers.mute(id, muted)
    {:noreply, socket}
  end

  def handle_in("channel-rename", [id, name], socket) do
    Otis.Channels.rename id, name
    {:noreply, socket}
  end

  def handle_in("receiver-rename", [id, name], socket) do
    Otis.Receivers.rename id, name
    {:noreply, socket}
  end

  def handle_in("playlist-clear", id, socket) do
    Otis.Channels.clear id
    {:noreply, socket}
  end

  def handle_in("channel-play_pause", [id, playing], socket) do
    Otis.Channels.play id, playing
    {:noreply, socket}
  end

  def handle_in("playlist-skip", [channel_id, "next"], socket) do
    Otis.Channels.skip channel_id, :next
    {:noreply, socket}
  end
  def handle_in("playlist-skip", [channel_id, rendition_id], socket) do
    Otis.Channels.skip channel_id, rendition_id
    {:noreply, socket}
  end

  def handle_in("playlist-remove", [channel_id, rendition_id], socket) do
    Otis.Channels.remove channel_id, rendition_id
    {:noreply, socket}
  end

  def handle_in("receiver-attach", [channel_id, receiver_id], socket) do
    Otis.Receivers.attach receiver_id, channel_id
    {:noreply, socket}
  end

  def handle_in("channel-add", channel_name, socket) do
    {:ok, _channel} = Otis.Channels.create(channel_name)
    {:noreply, socket}
  end

  def handle_in("channel-remove", channel_id, socket) do
    :ok = Otis.Channels.destroy!(channel_id)
    {:noreply, socket}
  end

  def handle_in("library-request", [channel_id, action, query], socket) do
    Strobe.Events.notify(:library, :request, [channel_id, action, socket, query])
    {:noreply, socket}
  end

  def handle_in("settings-retrieve", app, socket) do
    Strobe.Events.notify(:settings, :retrieve, [app, socket])
    {:noreply, socket}
  end

  def handle_in("settings-save", settings, socket) do
    Strobe.Events.notify(:settings, :save, [settings])
    {:noreply, socket}
  end

  def handle_in(unknown, args, socket) do
    Logger.warn "Unknown controller event #{inspect unknown} #{inspect args}"
    {:noreply, socket}
  end

  def handle_info(:controller_join, socket) do
    Strobe.Events.notify(:controller, :join, [socket])
    {:noreply, socket}
  end

  defp test_volume_change_interval(socket, module, args) do
    time = now()
    last_event_time = retrieve_volume_change(socket)
    case time - last_event_time do
      d when d >= @min_volume_change_interval_ms ->
        apply(module, :volume, args)
        assign_volume_change(socket, time)
      _ -> socket
    end
  end

  defp retrieve_volume_change(socket) do
    socket.assigns.volume_event_time
  end

  defp assign_volume_change(socket, time) do
    assign(socket, :volume_event_time, time)
  end

  defp now do
    :erlang.monotonic_time(:milli_seconds)
  end
end
