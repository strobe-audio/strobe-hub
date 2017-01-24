defmodule Elvis.ControllerChannel do
  use Phoenix.Channel

  @min_volume_change_interval_ms 50

  def join("controllers:" <> controller_type, _params, socket) do
    # Don't send the socket with the event because we can't send anything until
    # the channel has been joined (which happens when this function returns)
    # TODO: can use this event to send wakeup calls to the receivers
    Otis.State.Events.notify({:controller_connect, [controller_type]})
    send self(), :controller_join
    socket = assign_volume_change(socket, now())
    {:ok, socket}
  end

  def handle_in("change_volume", ["receiver", id, volume], socket) do
    socket = test_volume_change_interval(socket, Otis.Receivers, [id, volume])
    {:noreply, socket}
  end
  def handle_in("change_volume", ["channel", id, volume], socket) do
    socket = test_volume_change_interval(socket, Otis.Channels, [id, volume])
    {:noreply, socket}
  end

  def handle_in("rename_channel", [id, name], socket) do
    Otis.Channels.rename id, name
    {:noreply, socket}
  end

  def handle_in("rename_receiver", [id, name], socket) do
    Otis.Receivers.rename id, name
    {:noreply, socket}
  end

  def handle_in("clear_playlist", id, socket) do
    Otis.Channels.clear id
    {:noreply, socket}
  end

  def handle_in("play_pause", [id, playing], socket) do
    Otis.Channels.play id, playing
    {:noreply, socket}
  end

  def handle_in("skip_track", [channel_id, rendition_id], socket) do
    Otis.Channels.skip channel_id, rendition_id
    {:noreply, socket}
  end

  def handle_in("remove_rendition", [channel_id, rendition_id], socket) do
    Otis.Channels.remove channel_id, rendition_id
    {:noreply, socket}
  end

  def handle_in("attach_receiver", [channel_id, receiver_id], socket) do
    Otis.Receivers.attach receiver_id, channel_id
    {:noreply, socket}
  end

  def handle_in("add_channel", channel_name, socket) do
    {:ok, _channel} = Otis.Channels.create(channel_name)
    {:noreply, socket}
  end

  def handle_in("library", [channel_id, action], socket) do
    Otis.State.Events.notify({:library_request, [channel_id, action, socket]})
    {:noreply, socket}
  end

  def handle_info(:controller_join, socket) do
    Otis.State.Events.notify({:controller_join, [socket]})
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
