defmodule Elvis.ControllerChannel do
  use Phoenix.Channel

  def join("controllers:" <> controller_type, _params, socket) do
    # Don't send the socket with the event because we can't send anything until
    # the channel has been joined (which happens when this function returns)
    # TODO: can use this event to send wakeup calls to the receivers
    Otis.State.Events.notify({:controller_connect, controller_type})
    send self(), :controller_join
    {:ok, socket}
  end

  def handle_in("change_volume", ["receiver", id, volume], socket) do
    Otis.Receivers.volume id, volume
    {:noreply, socket}
  end
  def handle_in("change_volume", ["channel", id, volume], socket) do
    Otis.Zones.volume id, volume
    {:noreply, socket}
  end

  def handle_in("play_pause", [id, playing], socket) do
    Otis.Zones.play id, playing
    {:noreply, socket}
  end

  def handle_in("skip_track", [zone_id, source_id], socket) do
    Otis.Zones.skip zone_id, source_id
    {:noreply, socket}
  end

  def handle_in("attach_receiver", [zone_id, receiver_id], socket) do
    Otis.Receivers.attach receiver_id, zone_id
    {:noreply, socket}
  end

  def handle_in("library", [zone_id, action], socket) do
    Otis.State.Events.notify({:library_request, zone_id, action, socket})
    {:noreply, socket}
  end

  def handle_info(:controller_join, socket) do
    Otis.State.Events.notify({:controller_join, socket})
    {:noreply, socket}
  end
end
