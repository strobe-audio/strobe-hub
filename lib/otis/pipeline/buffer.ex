defmodule Otis.Pipeline.Buffer do
  use GenServer

  alias Otis.Pipeline.Producer
  alias Otis.Packet

  defmodule S do
    defstruct [
      :id,
      :packet_size,
      :buffer_size,
      :packet_duration_ms,
      :stream,
      n: 0,
      status: :ok,
      empty: false,
      buffer: <<>>,
    ]
  end

  defstruct [:pid]

  def new(id, stream, packet_size, packet_duration_ms, buffer_size) do
    {:ok, pid} = start_link(id, stream, packet_size, packet_duration_ms, buffer_size)
    %__MODULE__{pid: pid}
  end

  def next(pid) do
    GenServer.call(pid, :next)
  end

  def start_link(id, stream, packet_size, packet_duration_ms, buffer_size) do
    GenServer.start_link(__MODULE__, [id, stream, packet_size, packet_duration_ms, buffer_size])
  end

  def init([id, stream, packet_size, packet_duration_ms, buffer_size]) do
    {:ok, %S{
      id: id,
      packet_size: packet_size,
      buffer_size: (buffer_size * packet_size),
      packet_duration_ms: packet_duration_ms,
      stream: stream,
    }}
  end

  def handle_call(:next, _from, state) do
    {reply, state} =
      case next_packet(state) do
        {:done,  state} -> {:done, state}
        {packet, state} -> {{state.status, packet}, state}
      end
    {:reply, reply, state}
  end

  def next_packet(%S{status: :ok, buffer: buffer, buffer_size: s} = state) when byte_size(buffer) < s do
    state = append(Producer.next(state.stream), state)
    next_packet(state)
  end
  def next_packet(state) do
    packet(state)
  end

  defp append({:ok, data}, state) do
    %S{ state | buffer: (state.buffer <> data) }
  end
  defp append(:done, state) do
    %S{ state | status: :done }
  end

  defp packet(%S{status: :done, empty: true, packet_size: packet_size, buffer: buffer} = state) when byte_size(buffer) < packet_size do
    {:done, state}
  end
  defp packet(%S{status: :done, packet_size: packet_size, buffer: buffer} = state) when byte_size(buffer) == 0 do
    {:done, state}
  end
  defp packet(%S{status: :done, packet_size: packet_size, buffer: buffer} = state) when byte_size(buffer) < packet_size do
    packet(%S{ state | empty: true, buffer: buffer <> pad(packet_size, byte_size(buffer)) })
  end
  defp packet(%S{packet_size: packet_size} = state) do
    <<data::binary-size(packet_size), buffer::binary>> = state.buffer
    packet = %Packet{
      source_id: state.id,
      source_index: state.n,
      offset_ms: state.n * state.packet_duration_ms,
      duration_ms: state.packet_duration_ms,
      packet_size: state.packet_size,
      data: data,
    }
    {packet, %S{ state | n: state.n + 1, buffer: buffer }}
  end

  def pad(required_size, size) do
    :binary.copy(<<0>>, required_size - size)
  end
end

defimpl Otis.Pipeline.Producer, for: Otis.Pipeline.Buffer do
  alias Otis.Pipeline.Buffer

  def next(buffer) do
    Buffer.next(buffer.pid)
  end
end
