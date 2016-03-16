defmodule TestUtils do
  def packet(source_id, offset_ms \\ 0, duration_ms \\ 60_000, packet_size \\ 3528) do
    Otis.Packet.new(source_id, offset_ms, duration_ms, packet_size)
  end

  def md5(extract) do
    md5(extract, :crypto.hash_init(:md5))
  end

  defp md5(extract, md5) do
    _md5(extract.(), extract, md5)
  end

  defp _md5({:ok, data}, extract, md5) do
    _md5(extract.(), extract, :crypto.hash_update(md5, data))
  end

  defp _md5(:stopped, _extract, md5) do
    :crypto.hash_final(md5) |> Base.encode16 |> String.downcase
  end

  defp _md5(:done, _extract, md5) do
    :crypto.hash_final(md5) |> Base.encode16 |> String.downcase
  end

  def acc_stream(stream) do
    acc_stream(stream, <<>>)
  end

  defp acc_stream(stream, acc) do
    _acc_stream(stream, Otis.AudioStream.frame(stream), acc)
  end

  defp _acc_stream(stream, {:ok, packet}, acc) do
    _acc_stream(stream, Otis.AudioStream.frame(stream), << acc <> packet.data >>)
  end

  defp _acc_stream(_stream, :stopped, acc) do
    acc
  end
end

defmodule MockReceiver do
  alias Otis.Receivers

  defstruct [:id, :data_socket, :ctrl_socket, :latency]

  def connect!(id, latency, opts \\ []) do
    data_socket = data_connect(id, latency, opts)
    ctrl_socket = ctrl_connect(id, opts)
    %__MODULE__{id: id, data_socket: data_socket, ctrl_socket: ctrl_socket, latency: latency}
  end

  def ctrl_recv(%__MODULE__{ctrl_socket: socket}, timeout \\ 200) do
    recv_json(socket, timeout)
  end

  def data_recv(%__MODULE__{data_socket: socket}, timeout \\ 200) do
    recv_json(socket, timeout)
  end

  def data_recv_raw(%__MODULE__{data_socket: socket}, timeout \\ 200) do
    recv_raw(socket, timeout)
  end

  def data_reset(%__MODULE__{data_socket: socket} = receiver) do
    case :gen_tcp.recv(socket, 0, 1) do
      {:ok, _data} -> data_reset(receiver)
      {:error, _} -> nil
    end
  end

  defp recv_json(socket, timeout) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, data} -> Poison.decode(data)
      error -> error
    end
  end

  defp recv_raw(socket, timeout) do
    :gen_tcp.recv(socket, 0, timeout)
  end

  def data_connect(id, latency, opts \\ []) do
    {:ok, socket} = tcp_connect(Receivers.data_port, %{id: id, latency: latency}, opts)
    socket
  end

  def ctrl_connect(id, opts \\ []) do
    {:ok, socket} = tcp_connect(Receivers.ctrl_port, %{id: id}, opts)
    socket
  end

  defp tcp_connect(port, params, opts) do
    opts = Keyword.merge([mode: :binary, active: false, packet: 4, nodelay: true], opts)
    {:ok, socket} = :gen_tcp.connect({127,0,0,1}, port, opts)
    # :inet.setopts(socket, opts)
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
