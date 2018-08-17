defmodule TestUtils do
  def packet(source_id, offset_ms \\ 0, duration_ms \\ 60_000, packet_size \\ 3528) do
    Otis.Packet.new(source_id, offset_ms, duration_ms, packet_size)
  end

  def flush do
    receive do
      _ -> flush()
    after
      0 -> :ok
    end
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
    :crypto.hash_final(md5) |> Base.encode16(case: :lower)
  end

  defp _md5(:done, _extract, md5) do
    :crypto.hash_final(md5) |> Base.encode16(case: :lower)
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

  def data_reset(%__MODULE__{data_socket: socket}) do
    reset(socket)
  end

  def ctrl_reset(%__MODULE__{ctrl_socket: socket}) do
    reset(socket)
  end

  defp reset(socket) do
    case :gen_tcp.recv(socket, 0, 1) do
      {:ok, _data} -> reset(socket)
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
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, opts)
    # :inet.setopts(socket, opts)
    :gen_tcp.send(socket, Poison.encode!(params))
    {:ok, socket}
  end
end

defmodule MessagingHandler do
  use GenStage
  use Strobe.Events.Handler, filter_complete: false

  def attach do
    {:ok, _pid} = start_link(self())
    :ok
  end

  def start_link(parent) do
    GenStage.start_link(__MODULE__, parent)
  end

  def init(parent) do
    {:consumer, parent, subscribe_to: Strobe.Events.producer}
  end

  def handle_event(event, parent) do
    send(parent, event)
    {:ok, parent}
  end

  # Allows tests to wait for successful removal of the handler
  #
  #    on_exit fn ->
  #      Strobe.Events.remove_handler(MessagingHandler, self())
  #      assert_receive :remove_messaging_handler, 200
  #    end

  def terminate(pid, _parent)
  when is_pid(pid) do
    send(pid, :remove_messaging_handler)
    :ok
  end
  def terminate(_reason, _state) do
    :ok
  end
end

defmodule Otis.Test.TestSource do
  @silence :binary.copy(<< 0 >>, 1024)
  defstruct [
    :id,
    duration: 60_000,
    loaded: false,
    data: @silence,
  ]

  def new(duration \\ 60_000) do
    %__MODULE__{id: Otis.uuid(), duration: duration}
  end
end

defimpl Otis.Library.Source, for: Otis.Test.TestSource do
  def id(source) do
    source.id
  end

  def type(_source) do
    Otis.Test.TestSource
  end

  def open!(source, _id, _packet_size_bytes) do
    Stream.repeatedly(fn -> source.data end)
  end

  def pause(_source, _id, _stream) do
    :ok
  end

  def close(_source, _id, _stream) do
    :ok
  end

  def transcoder_args(_track) do
    :passthrough
  end

  def metadata(_track) do
    # noop
  end

  def duration(track) do
    {:ok, track.duration}
  end
end

defimpl Otis.Library.Source.Origin, for: Otis.Test.TestSource do
  def load!(source) do
    %Otis.Test.TestSource{source | loaded: true}
  end
end


defmodule Test.CycleSource do
  use GenServer

  alias Otis.Library.Source
  alias Otis.State.Rendition

  @table :cycle_sources

  defstruct [:id, :source, :cycles, :parent, :type, :delay]

  def start_table() do
    :ets.new(@table, [:set, :public, :named_table])
    :ok
  end

  def save(source) do
    save(source.id, source)
  end
  def save(id, source) do
    :ets.insert(@table, {id, source})
    source
  end

  def find(id) do
    [{_, source}] = :ets.lookup(@table, id)
    {:ok, source}
  end

  def source_id(table, id) do
    Enum.join([table, id], ":")
  end
  def source_id(id) when is_binary(id) do
    String.split(id, ":")
  end

  def new(source, cycles \\ 1, type \\ :file, delay \\ 0) do
    # {:ok, pid} = start_link(source, cycles, type)
    %__MODULE__{id: Otis.uuid(), source: source, cycles: cycles, type: type, delay: delay}
  end

  def rendition!(channel_id, source, cycles \\ 1, type \\ :file, delay \\ 0) do
    rendition(channel_id, source, cycles, type, delay) |> Rendition.create!
  end
  def rendition(channel_id, source, cycles \\ 1, type \\ :file, delay \\ 0) do
    new(source, cycles, type, delay) |> save() |> source_rendition(channel_id)
  end
  def source_rendition(source, channel_id) do
    %Rendition{id: source.id, channel_id: channel_id, source_type: Source.type(source), source_id: source.id, playback_duration: 1000, playback_position: 0, position: 0}
  end

  def start_link(source) do
    GenServer.start_link(__MODULE__, source)
  end

  def init(%__MODULE__{source: source, cycles: cycles, type: type, delay: delay}) do
    state = %{source: source, sink: [], cycles: cycles, type: type, delay: delay}
    {:ok, state}
  end

  def handle_call(:next, _from, %{cycles: cycles} = state) when cycles == 0 do
    {:reply, :done, state}
  end
  def handle_call(:next, from, %{source: [], sink: sink, cycles: cycles} = state) do
    source = Enum.reverse(sink)
    handle_call(:next, from, %{state | source: source, sink: [], cycles: cycles - 1})
  end
  def handle_call(:next, from, %{delay: delay} = state) when delay > 0 do
    Process.send_after(self(), {:delayed, from}, delay)
    {:noreply, %{state | delay: 0}}
  end
  def handle_call(:next, _from, %{source: [h | t], sink: sink} = state) do
    {:reply, {:ok, h}, %{state | source: t, sink: [h | sink]}}
  end

  def handle_info({:delayed, from}, %{source: [h | t], sink: sink} = state) do
    GenServer.reply(from, {:ok, h})
    {:noreply, %{state | source: t, sink: [h | sink]}}
  end
end

defimpl Otis.Library.Source, for: Test.CycleSource do
  alias Test.CycleSource, as: S

  def id(%S{id: id} = _source) do
    id
  end

  def type(_source) do
    Test.CycleSource |> to_string
  end

  def open!(source, _id, _packet_size_bytes) do
    {:ok, pid} = S.start_link(source)
    Otis.Pipeline.Producer.stream(pid)
  end

  def pause(%S{type: :file}, _id, _stream) do
    :ok
  end
  def pause(%S{type: :live}, _id, _stream) do
    :stop
  end

  def close(_file, _id, _stream) do
    :ok
  end

  def transcoder_args(_source) do
    :passthrough
  end

  def metadata(_source) do
    %{}
  end
  def duration(%S{type: :live}) do
    {:ok, :infinity}
  end
  def duration(_source) do
    {:ok, 100_000}
  end
end

defmodule Test.PassthroughTranscoder do
  use GenServer

  def start_link(_source, inputstream, _playback_position, _config) do
    GenServer.start_link(__MODULE__, inputstream)
  end

  def init(stream) do
    {:ok, stream}
  end

  def handle_call(:next, _from, stream) do
    resp = case Enum.take(stream, 1) do
      [] -> :done
      [v] -> {:ok, v}
    end
    {:reply, resp, stream}
  end
end

defimpl Otis.Library.Source.Origin, for: Test.CycleSource do
  alias Test.CycleSource
  def load!(%CycleSource{id: id} = _source) do
    {:ok, source} = CycleSource.find(id)
    source
  end
end

defmodule Test.Otis.Pipeline.Clock do
  use GenServer

  def start_link(time) do
    start_link(self(), time)
  end
  def start_link(parent, time) do
    GenServer.start_link(__MODULE__, [parent, time])
  end

  def init([parent, time]) do
    {:ok, {parent, time, nil}}
  end

  def handle_call({:start, broadcaster, interval_ms}, _from, {parent, time, _}) do
    Kernel.send(parent, {:clock, {:start, broadcaster, interval_ms}})
    {:reply, {:ok, time}, {parent, time, broadcaster}}
  end

  def handle_call({:tick, _}, _from, {_parent, _time, nil} = state) do
    {:reply, {:error, :no_broadcaster}, state}
  end
  def handle_call({:tick, time}, _from, {parent, _time, broadcaster}) do
    Otis.Pipeline.Clock.tick(broadcaster, time)
    {:reply, :ok, {parent, time, broadcaster}}
  end
  def handle_call({:set_time, time}, _from, {parent, _time, broadcaster}) do
    {:reply, :ok, {parent, time, broadcaster}}
  end
  def handle_call(:time, _from, {parent, time, broadcaster}) do
    {:reply, {:ok, time}, {parent, time, broadcaster}}
  end

  def handle_call(:stop, _from, {parent, time, _broadcaster}) do
    Kernel.send(parent, {:clock, {:stop}})
    {:reply, {:ok, time}, {parent, time, nil}}
  end

  def handle_info({:set_time, time}, {parent, _time, broadcaster}) do
    {:noreply, {parent, time, broadcaster}}
  end
end

Ecto.Migrator.run(Otis.State.Repo, Path.join([__DIR__, "../priv/repo/migrations"]), :up, all: true)
Ecto.Adapters.SQL.begin_test_transaction(Otis.State.Repo)

ExUnit.configure(exclude: [skip: true])
ExUnit.start(assert_receive_timeout: 500)
