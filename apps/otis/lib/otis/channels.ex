defmodule Otis.Channels do
  use Supervisor

  alias Otis.State.Channel

  import Otis.Registry

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
    case stop(id) do
      :ok ->
        Strobe.Events.notify(:channel, :remove, [id])
        :ok
      err ->
        err
    end
  end

  def stop({:via, _m, _n} = id) do
    stop(GenServer.whereis(id))
  end
  def stop(pid) when is_pid(pid) do
    Supervisor.terminate_child(@supervisor, pid)
  end
  def stop(id) when is_binary(id) do
    stop(via(id))
  end
  def stop(nil) do
    {:error, :not_found}
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
    case whereis(id) do
      pid when is_pid(pid) ->
        {:ok, pid}
      _ ->
        :error
    end
  end

  def volume(%Otis.Channel{} = channel) do
    Otis.Channel.volume(channel)
  end
  def volume(id) do
    Otis.Channel.volume(via(id))
  end

  def volume(id, volume, opts \\ []) do
    Otis.Channel.volume(via(id), volume, opts)
  end

  def playing?(id) when is_binary(id) do
    Otis.Channel.playing?(via(id))
  end

  def play(id, playing) when is_binary(id) do
    Otis.Channel.play(via(id), playing)
  end

  def skip(id, source_id) do
    Otis.Channel.skip(via(id), source_id)
  end

  def remove(id, rendition_id) do
    Otis.Channel.remove(via(id), rendition_id)
  end

  def rename(id, name) when is_binary(id) do
    Strobe.Events.notify(:channel, :rename, [id, name])
  end

  def clear(id) when is_binary(id) do
    Otis.Channel.clear(via(id))
  end

  defp add(action, registry, channel, config) do
    start_channel(registry, channel, config) |> notify(action, channel)
  end

  defp notify(pid, :start, _channel) do
    pid
  end
  defp notify(pid, :create, channel) do
    Strobe.Events.notify(:channel, :add, [channel.id, channel])
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
end
