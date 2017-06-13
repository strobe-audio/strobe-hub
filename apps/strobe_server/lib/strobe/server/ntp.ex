defmodule Strobe.Server.Ntp do
  use     GenServer
  require Logger

  @name __MODULE__

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)
    send(self(), :start)
    {:ok, %{port: nil}}
  end

  def handle_info(:start, state) do
    Logger.info "#{__MODULE__} starting #{ntpd_daemon()}"
    port = Port.open({:spawn_executable, ntpd_daemon()}, ntpd_daemon_args())
    Strobe.Server.Events.notify({:running, [:ntpd]})
    {:noreply, %{ state | port: port }}
  end
  def handle_info(_evt, state) do
    {:noreply, state}
  end

  def terminate(_reason, %{port: nil}) do
    :ok
  end
  def terminate(_reason, %{port: port}) do
    Port.close(port)
    :ok
  end

  def ntpd_daemon do
    System.find_executable("ntpd")
  end

  def ntpd_daemon_args do
    [ :stderr_to_stdout,
      :binary,
      line: 4096,
      args: args(),
    ]
  end

  # -d       Verbose
  # -n       Do not daemonize
  # -q       Quit after clock is set
  # -N       Run at high priority
  # -w       Do not set time (only query peers), implies -n
  # -S PROG  Run PROG after stepping time, stratum change, and every 11 mins
  # -p PEER  Obtain time from PEER (may be repeated)
  #          If -p is not given, 'server HOST' lines
  #          from /etc/ntp.conf are used
  def args do
    ["-p", "pool.ntp.org", "-n", "-d"]
  end
end
