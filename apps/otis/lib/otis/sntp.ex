defmodule Otis.SNTP do
  require Logger
  use Supervisor

  @name Otis.SNTP

  def start_link(port \\ 5045) do
    Supervisor.start_link(__MODULE__, port, name: @name)
  end

  def init(port) do
    listener_pool_options = [
      name: {:local, Otis.SNTPPool},
      worker_module: Otis.SNTP.Worker,
      size: 6,
      max_overflow: 2
    ]

    children = [
      :poolboy.child_spec(Otis.SNTPPool, listener_pool_options, pool: Otis.SNTPPool),
      worker(Otis.SNTP.Listener, [port, Otis.SNTPPool], [])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defmodule Listener do
    use Monotonic
    use GenServer
    require Logger

    def start_link(port, pool) do
      GenServer.start_link(__MODULE__, [port, pool])
    end

    def init([port, pool]) do
      Logger.info("Starting SNTP socket listener on port #{port}...")

      {:ok, socket} =
        :gen_udp.open(port,
          mode: :binary,
          ip: {0, 0, 0, 0},
          active: :once,
          reuseaddr: true
        )

      Process.flag(:priority, :high)
      {:ok, {socket, pool}}
    end

    def terminate(_reason, {socket, _pool}) do
      Logger.info("Closing SNTP socket listener...")
      :gen_udp.close(socket)
      :ok
    end

    def handle_info({:udp, socket, address, port, packet}, {_socket, pool} = state) do
      now = monotonic_microseconds()
      worker = :poolboy.checkout(pool)
      GenServer.cast(worker, {:reply, socket, address, port, packet, now})
      :inet.setopts(socket, active: :once)
      {:noreply, state}
    end
  end

  defmodule Worker do
    use GenServer
    use Monotonic
    require Logger

    def start_link(pool: pool) do
      GenServer.start_link(__MODULE__, [pool])
    end

    def init([pool]) do
      Logger.info("Starting SNTP worker in pool #{pool}...")
      Process.flag(:priority, :high)
      {:ok, pool}
    end

    def handle_cast({:reply, socket, address, port, packet, receive_ts}, pool) do
      reply(socket, address, port, packet, receive_ts)
      :poolboy.checkin(pool, self())
      {:noreply, pool}
    end

    defp reply(socket, address, port, packet, receive_ts) do
      <<
        count::size(64)-little-unsigned-integer,
        originate_ts::size(64)-little-signed-integer
      >> = packet

      reply = <<
        count::size(64)-little-unsigned-integer,
        originate_ts::size(64)-little-signed-integer,
        receive_ts::size(64)-little-signed-integer,
        monotonic_microseconds()::size(64)-little-signed-integer
      >>

      :gen_udp.send(socket, address, port, reply)
    end
  end
end
