defmodule Otis.Receivers.Proxy do
  @moduledoc """
  This process registers itself with the receiver set registry and monitors the
  given receiver. When the receiver goes down, this process exits too and is
  hence removed from the registry.
  """

  use GenServer

  require Logger

  alias Otis.Receiver

  def start_link(receiver, channel) do
    GenServer.start_link(__MODULE__, [receiver, channel])
  end

  def init([receiver, channel]) do
    Receiver.monitor(receiver)
    Otis.Receivers.Channels.register(receiver, channel)
    {:ok, {receiver, channel}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, {receiver, channel}) do
    Otis.Receivers.Channels.notify_remove_receiver(receiver, channel)
    {:stop, :normal, receiver}
  end
end
