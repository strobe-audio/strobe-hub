defmodule Strobe.Server.Dbus do
  use     GenServer
  require Logger

  @name __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init(_opts) do
    send(self(), :start)
    {:ok, %{port: nil}}
  end

  def handle_info(:start, state) do
    Logger.info "#{__MODULE__} starting #{dbus_daemon()}"
    File.mkdir_p("/var/run/dbus")
    port = Port.open({:spawn_executable, dbus_daemon()}, dbus_daemon_args())
    Strobe.Server.Events.notify({:running, [:dbus]})
    {:noreply, %{state | port: port}}
  end

  def handle_info({port, {:data, {:eol, msg}}}, %{port: port} = state) do
    IO.inspect [__MODULE__, String.trim(msg)]
    {:noreply, state}
  end
  def handle_info(evt, state) do
    IO.inspect [__MODULE__, evt]
    {:noreply, state}
  end

  def dbus_daemon do
    System.find_executable("dbus-daemon")
  end

  def dbus_daemon_args do
    [ :stderr_to_stdout,
      :binary,
      line: 4096,
      # args: ["--system", "--address", dbus_address(), "--nofork", "--nopidfile"],
      args: ["--system", "--nofork", "--nopidfile"],
    ]
  end

  def dbus_socket do
    "/tmp/dbus.sock"
  end

  def dbus_address do
    "unix:path=#{dbus_socket()}"
  end
end

