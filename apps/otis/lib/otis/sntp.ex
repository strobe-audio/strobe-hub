
defmodule Otis.SNTP do
  require Logger
  use     Supervisor

  @name      Otis.SNTP
  @listeners 6

  def start_link(port \\ 5045) do
    Supervisor.start_link(__MODULE__, port, name: @name)
  end

  def init(port) do

    children = [
      worker(Otis.SNTP.Listener, [port], [])
    ]
    spawn_link(&start_listeners/0)
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_listener(_n) do
    start_listener
  end

  def start_listener do
    Supervisor.start_child(__MODULE__, [])
  end

  def start_listeners do
    Enum.each 1..@listeners, &start_listener/1
  end

  defmodule Listener do
    use     Monotonic
    use     GenServer
    require Logger

    def start_link(port) do
      GenServer.start_link(__MODULE__, [port])
      :proc_lib.start_link(__MODULE__, :init, [port])
    end

    def init([port]) do
      Logger.info "Starting SNTP socket listener on port #{ port }..."
      {:ok, socket} = :gen_udp.open port, [
        mode: :binary,
        ip: {0, 0, 0, 0},
        active: :once,
        reuseaddr: true
      ]
      Process.flag :priority, :high
      {:ok, {socket}}
    end

    def handle_info({:udp, _socket, address, port, packet}, {socket} = state) do
      reply(socket, address, port, packet, monotonic_microseconds)
      :inet.setopts(socket, [active: :once])
      {:noreply, state}
    end

    def reply(socket, address, port, packet, receive_ts) do
      <<
        count        ::size(64)-little-unsigned-integer,
        originate_ts ::size(64)-little-signed-integer
      >> = packet

      reply = <<
        count        ::size(64)-little-unsigned-integer,
        originate_ts ::size(64)-little-signed-integer,
        receive_ts   ::size(64)-little-signed-integer,
        monotonic_microseconds::size(64)-little-signed-integer
      >>

      :gen_udp.send socket, address, port, reply
    end
  end
end

