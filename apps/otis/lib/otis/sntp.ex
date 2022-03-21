defmodule Otis.SNTP do
  require Logger
  use Supervisor

  @name Otis.SNTP
  @default_port 5045

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    port = Keyword.get(args, :port, @default_port)
    listeners = Keyword.get(args, :listeners, 20)

    children = Enum.map(1..listeners, &{Otis.SNTP.Listener, port: port, id: &1})

    Supervisor.init(children, strategy: :one_for_one)
  end

  defmodule Listener do
    use Monotonic

    require Logger

    def child_spec(args) do
      {:ok, id} = Keyword.fetch(args, :id)

      default = %{
        id: {__MODULE__, id},
        start: {__MODULE__, :start_link, [args]}
      }

      Supervisor.child_spec(default, [])
    end

    def start_link(args) do
      pid = spawn_link(__MODULE__, :init, [args])
      {:ok, pid}
    end

    def init(args) do
      {:ok, port} = Keyword.fetch(args, :port)
      {:ok, id} = Keyword.fetch(args, :id)
      Logger.info("Starting SNTP socket listener #{id} on port #{port}...")

      {:ok, socket} = :socket.open(:inet, :dgram, :udp)

      :ok = :socket.setopt(socket, :socket, :reuseport, true)
      :ok = :socket.setopt(socket, :socket, :reuseaddr, true)
      :ok = :socket.bind(socket, %{family: :inet, port: port, addr: :any})

      Process.flag(:priority, :high)

      loop(socket, id, monotonic_microseconds(), 0)
    end

    # simulate a bad clock that's fast or slow
    # @drift_us_per_day 2_000_000
    @drift_us_per_day 0

    @compile {:inline, now: 2}

    if @drift_us_per_day != 0 do
      @us_per_day 1_000_000 * 3600 * 24

      defp now(now, t0) do
        drift = (now - t0) / @us_per_day * @drift_us_per_day
        round(now + drift)
      end
    else
      defp now(now, _t0) do
        now
      end
    end

    defp loop(socket, id, t0, n) do
      {:ok, {source, packet}} = :socket.recvfrom(socket, [], :infinity)

      receive_ts =
        monotonic_microseconds()
        |> now(t0)

      <<
        count::size(64)-little-unsigned-integer,
        originate_ts::size(64)-little-signed-integer
      >> = packet

      reply_ts =
        monotonic_microseconds()
        |> now(t0)

      reply = <<
        count::size(64)-little-unsigned-integer,
        originate_ts::size(64)-little-signed-integer,
        receive_ts::size(64)-little-signed-integer,
        reply_ts::size(64)-little-signed-integer
      >>

      :socket.sendto(socket, reply, source)

      loop(socket, id, t0, n + 1)
    end
  end
end
