defmodule Strobe.Server.Avahi do
  use     GenServer
  require Logger

  @name __MODULE__

  def start_link(dev) do
    GenServer.start_link(__MODULE__, dev, name: @name)
  end

  def init(dev) do
    Registry.register(Nerves.NetworkInterface, dev, [])
    {:ok, %{port: nil}}
  end

  def handle_info({Nerves.NetworkInterface, :ifchanged, %{operstate: :up}}, %{port: nil} = state) do
    Logger.info "#{__MODULE__} starting #{avahi_daemon()}"
    port = Port.open({:spawn_executable, avahi_daemon()}, avahi_daemon_args())
    Process.send_after(self(), :check_running, 1_000)
    {:noreply, %{state | port: port}}
  end
  def handle_info(:check_running, state) do
    IO.inspect [__MODULE__, :check_running]
    if is_running?() do
      Strobe.Server.Events.notify({:running, [:avahi]})
    else
      Process.send_after(self(), :check_running, 1_000)
    end
    {:noreply, state}
  end

  def handle_info({port, {:data, {:eol, msg}}}, %{port: port} = state) do
    IO.inspect [__MODULE__, String.trim(msg)]
    {:noreply, state}
  end
  def handle_info(evt, state) do
    IO.inspect [__MODULE__, evt]
    {:noreply, state}
  end

  def avahi_daemon do
    System.find_executable("avahi-daemon")
  end

  def avahi_daemon_args(args \\ []) do
    [ :stderr_to_stdout,
      :binary,
      line: 4096,
      args: args,
    ]
  end

  def is_running? do
    case System.cmd(avahi_daemon(), ["--check"]) do
      {_, 0} ->
        true
      _ ->
        false
    end
  end
end

