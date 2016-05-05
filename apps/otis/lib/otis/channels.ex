defmodule Otis.Channels do
  use GenServer

  @registry_name Otis.Channels

  def start_link( name \\ @registry_name ) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def create(id, name) do
    create(@registry_name, id, name)
  end

  def create(registry, id, name) do
    add(:create, registry, id, %Otis.State.Channel{id: id, name: name})
  end

  @doc "Start an existing channel"
  def start(%Otis.State.Channel{} = channel) do
    start(@registry_name, channel.id, channel)
  end
  def start(id, config) do
    start(@registry_name, id, config)
  end

  def start(registry, id, config) do
    add(:start, registry, id, config)
  end

  def destroy!(id) do
    destroy!(@registry_name, id)
  end

  def destroy!(registry, id) do
    {:ok, channel} = find(registry, id)
    response = Otis.Channels.Supervisor.stop_channel(channel)
    remove(registry, id)
    response
  end

  def list! do
    list!(@registry_name)
  end

  def list!(registry) do
    {:ok, channels} = list(registry)
    channels
  end

  def list do
    list(@registry_name)
  end

  def list(pid) do
    GenServer.call(pid, :list)
  end

  def find!(id) do
    find!(@registry_name, id)
  end
  def find!(registry, id) do
    {:ok, pid} = find(registry, id)
    pid
  end

  def find(id) do
    find(@registry_name, id)
  end

  def find(pid, id) do
    GenServer.call(pid, {:find, id})
  end

  def volume(%Otis.Channel{} = channel) do
    Otis.Channel.volume(channel)
  end
  def volume(id) do
    volume(@registry_name, id)
  end
  def volume(registry, id)
  when is_binary(id) do
    Otis.Channel.volume(find!(registry, id))
  end

  def volume(id, volume) when is_binary(id) do
    volume(@registry_name, id, volume)
  end
  def volume(registry, id, volume) do
    Otis.Channel.volume(find!(registry, id), volume)
  end

  def playing?(id) when is_binary(id) do
    playing?(@registry_name, id)
  end
  def playing?(registry, id) when is_binary(id) do
    Otis.Channel.playing?(find!(registry, id))
  end
  def play(id, playing) when is_binary(id) do
    play(@registry_name, id, playing)
  end
  def play(registry, id, playing) when is_binary(id) do
    Otis.Channel.play(find!(registry, id), playing)
  end

  def skip(id, source_id) when is_binary(id) do
    skip(@registry_name, id, source_id)
  end
  def skip(registry, id, source_id) do
    Otis.Channel.skip(find!(registry, id), source_id)
  end

  defp add(action, registry, id, config) do
    {:ok, channel} = Otis.Channels.Supervisor.start_channel(id, config)
    add(action, registry, channel, id, config)
  end
  defp add(action, registry, channel, id, config) do
    GenServer.call(registry, {action, channel, id, config})
  end

  defp remove(pid, id) do
    GenServer.cast(pid, {:remove, id})
  end

  ############# Callbacks

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call(:list, _from, channel_list) do
    {:reply, {:ok, Map.values(channel_list)}, channel_list}
  end

  def handle_call({:find, id}, _from, channel_list) do
    {:reply, Map.fetch(channel_list, id), channel_list}
  end

  def handle_call({:create, channel, id, config}, _from, channel_list) do
    Otis.State.Events.notify({:channel_added, id, config})
    insert(channel_list, id, channel)
  end

  def handle_call({:start, channel, id, _config}, _from, channel_list) do
    insert(channel_list, id, channel)
  end

  def handle_cast({:remove, id}, channel_list) do
    Otis.State.Events.notify({:channel_removed, id})
    {:noreply, Map.delete(channel_list, id)}
  end

  defp insert(channel_list, id, channel) do
    {:reply, {:ok, channel}, Map.put(channel_list, id, channel)}
  end
end
