defmodule Otis.Receivers.Sets do
  use Supervisor

  alias Otis.Receiver
  @supervisor_name __MODULE__
  @set_registry Otis.Receivers.SetRegistry
  @subscriber_registry Otis.Receivers.SubscriberRegistry

  def set_namespace, do: @set_registry
  def subscriber_namespace, do: @subscriber_registry

  def add_receiver(receiver, channel) do
    {:ok, _proxy} = Supervisor.start_child(@supervisor_name, [receiver, channel])
    notify_add_receiver(receiver, channel)
  end

  def register(receiver, channel) do
    Registry.register(@set_registry, channel.id, receiver)
  end

  def lookup(channel_id) do
    @set_registry |> Registry.lookup(channel_id) |> Enum.map(&elem(&1, 1))
  end

  def subscribe(name, channel_id) do
    Registry.register(@subscriber_registry, channel_id, name)
  end

  def subscribers(channel_id) do
    @subscriber_registry |> Registry.lookup(channel_id)
  end

  def notify_add_receiver(receiver, channel) do
    Enum.each(subscribers(channel.id), fn({pid, _name}) ->
      send pid, {:receiver_joined, [receiver.id, receiver]}
    end)
  end

  def notify_remove_receiver(receiver, channel) do
    Enum.each(subscribers(channel.id), fn({pid, _name}) ->
      send pid, {:receiver_left, [receiver.id, receiver]}
    end)
  end

  def send_data(channel_id, data) do
    Enum.each(lookup(channel_id), fn(r) ->
      Receiver.send_data(r, data)
    end)
  end

  def volume_multiplier(channel_id, volume) do
    Enum.each(lookup(channel_id), fn(r) ->
      Receiver.volume_multiplier(r, volume)
    end)
  end

  def stop(channel_id) do
    Enum.each(lookup(channel_id), fn(r) ->
      Receiver.stop(r)
    end)
  end

  def latency(channel_id) do
    channel_id |> lookup() |> Enum.map(&Receiver.latency!/1) |> Enum.max()
  end

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def init(:ok) do
    children = [
      worker(Otis.Receivers.Proxy, [], [restart: :temporary])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
