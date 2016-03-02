
defmodule MockReceiver do
  alias Otis.ReceiverSocket, as: RS
  defstruct [:id, :data_socket, :ctrl_socket, :latency]

  def connect!(id, latency, opts \\ []) do
    data_socket = data_connect(id, latency, opts)
    ctrl_socket = ctrl_connect(id, opts)
    %__MODULE__{id: id, data_socket: data_socket, ctrl_socket: ctrl_socket, latency: latency}
  end

  def ctrl_recv(%__MODULE__{ctrl_socket: socket}, timeout \\ 200) do
    recv(socket, timeout)
  end

  def data_recv(%__MODULE__{data_socket: socket}, timeout \\ 200) do
    recv(socket, timeout)
  end

  defp recv(socket, timeout) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, data} -> Poison.decode(data)
      error -> error
    end
  end

  def data_connect(id, latency, opts \\ []) do
    {:ok, socket} = tcp_connect(RS.data_port, %{id: id, latency: latency}, opts)
    socket
  end

  def ctrl_connect(id, opts \\ []) do
    {:ok, socket} = tcp_connect(RS.ctrl_port, %{id: id}, opts)
    socket
  end

  defp tcp_connect(port, params, opts) do
    opts = Keyword.merge([mode: :binary, active: false, packet: 4], opts)
    {:ok, socket} = :gen_tcp.connect({127,0,0,1}, port, opts)
    :gen_tcp.send(socket, Poison.encode!(params))
    {:ok, socket}
  end
end


defmodule MessagingHandler do
  use GenEvent

  def attach do
    :ok = Otis.State.Events.add_mon_handler(__MODULE__, self)
  end

  def init(parent) do
    {:ok, parent}
  end

  def handle_event(event, parent) do
    send(parent, event)
    {:ok, parent}
  end

  # Allows tests to wait for successful removal of the handler
  #
  #    on_exit fn ->
  #      Otis.State.Events.remove_handler(MessagingHandler, self)
  #      assert_receive :remove_messaging_handler, 200
  #    end

  def terminate(pid, _parent)
  when is_pid(pid) do
    send(pid, :remove_messaging_handler)
    :ok
  end
end

Faker.start
Ecto.Migrator.run(Otis.State.Repo, Path.join([__DIR__, "../priv/repo/migrations"]), :up, all: true)
Ecto.Adapters.SQL.begin_test_transaction(Otis.State.Repo)

ExUnit.start()
