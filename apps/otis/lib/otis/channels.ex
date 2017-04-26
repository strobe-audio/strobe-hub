defmodule Otis.Channels do
  use Supervisor

  alias Otis.State.Channel

  @supervisor __MODULE__

  def create(name) when is_binary(name) do
    create(Otis.uuid(), name)
  end
  def create(id, name) do
    create(@supervisor, id, name)
  end
  def create(id, name, %Otis.Pipeline.Config{} = config) do
    create(@supervisor, id, name, config)
  end
  def create(registry, id, name) when is_binary(id) and is_binary(name) do
    create(registry, id, name, Otis.Pipeline.config())
  end
  def create(registry, id, name, config) do
    add(:create, registry, %Channel{id: id, name: name}, config)
  end

  @doc "Start an existing channel"
  def start(%Channel{} = channel, config \\ Otis.Pipeline.config()) do
    start(@supervisor, channel, config)
  end
  def start(registry, channel, config) do
    add(:start, registry, channel, config)
  end


  def destroy!(id) do
    case whereis_name(id) do
      :undefined ->
        nil
      pid when is_pid(pid) ->
        response = Supervisor.terminate_child(@supervisor, whereis_name(id))
        Otis.Events.notify({:channel_removed, [id]})
        response
    end
  end

  def stop({:via, _m, _n} = id) do
    stop(GenServer.whereis(id))
  end
  def stop(pid) when is_pid(pid) do
    Supervisor.terminate_child(@supervisor, pid)
  end

  def ids do
    list!() |> Enum.map(&Otis.Channel.id!/1)
  end

  def list! do
    {:ok, channels} = list()
    channels
  end

  def list do
    list(@supervisor)
  end
  def list(supervisor) do
    pids = supervisor
    |> Supervisor.which_children()
    |> Enum.map(fn({_id, pid, :worker, [Otis.Channel]}) -> pid end)
    {:ok, pids}
  end

  def find!(id) do
    {:ok, pid} = find(id)
    pid
  end

  def find(id) do
    case whereis_name(id) do
      :undefined -> :error
      nil -> :error
      pid when is_pid(pid) -> {:ok, pid}
    end
  end

  def volume(%Otis.Channel{} = channel) do
    Otis.Channel.volume(channel)
  end
  def volume(id) do
    Otis.Channel.volume(whereis_name(id))
  end

  def volume(id, volume) do
    Otis.Channel.volume(whereis_name(id), volume)
  end

  def playing?(id) when is_binary(id) do
    Otis.Channel.playing?(whereis_name(id))
  end

  def play(id, playing) when is_binary(id) do
    Otis.Channel.play(whereis_name(id), playing)
  end

  def skip(id, source_id) do
    Otis.Channel.skip(whereis_name(id), source_id)
  end

  def remove(id, rendition_id) do
    Otis.Channel.remove(whereis_name(id), rendition_id)
  end

  def rename(id, name) when is_binary(id) do
    Otis.Events.notify({:channel_rename, [id, name]})
  end

  def clear(id) when is_binary(id) do
    Otis.Channel.clear(whereis_name(id))
  end

  defp add(action, registry, channel, config) do
    start_channel(registry, channel, config) |> notify(action, channel)
  end

  defp notify(pid, :start, _channel) do
    pid
  end
  defp notify(pid, :create, channel) do
    Otis.Events.notify({:channel_added, [channel.id, channel]})
    pid
  end

  defp start_channel(supervisor, channel, config) do
    process_name = via(channel.id)
    Supervisor.start_child(supervisor, [channel, config, process_name])
    {:ok, process_name}
  end

  ############# Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor)
  end

  def init(:ok) do
    children = [
      worker(Otis.Channel, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  ### Registry functions & callbacks

  def register_name(id, pid) do
    id |> key |> :gproc.register_name(pid)
  end

  def unregister_name(id) do
    id |> key |> :gproc.unregister_name
  end

  def whereis_name(id) do
    id |> key |> :gproc.whereis_name
  end

  def send(id, msg) do
    id |> key |> :gproc.send(msg)
  end

  def via(id) do
    {:via, __MODULE__, id}
  end

  defp key(id) do
    {:n, :l, {__MODULE__, String.to_atom(id)}}
  end
end
