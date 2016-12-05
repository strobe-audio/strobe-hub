defmodule Otis.Pipeline.Buffer do
  use GenServer

  alias Otis.State.Rendition
  alias Otis.Library.Source

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

  def start_link(name, rendition, config, transcoder_module) do
    GenServer.start_link(__MODULE__, [rendition, config, transcoder_module], [name: name])
  end

  def init([rendition, config, transcoder_module]) do
    source = Rendition.source(rendition)
    stream = Source.open!(source, rendition.id, config.packet_size)
    {:ok, transcoder} = transcoder(transcoder_module, rendition, source, stream)
    {:ok, %S{
      id: rendition.id,
      packet_size: config.packet_size,
      buffer_size: (config.buffer_packets * config.packet_size),
      packet_duration_ms: config.packet_duration_ms,
      stream: transcoder,
    }}
  end

  defp transcoder(transcoder_module, rendition, source, stream) do
    Kernel.apply(transcoder_module, :start_link, [source, stream, rendition.playback_position])
  end

  def handle_call(:stream, _from, state) do
    {:reply, {:ok, state.stream}, state}
  end
  def handle_call(:next, _from, state) do
    case next_packet(state) do
      {:done,  state} -> {:stop, {:shutdown, :normal}, :done, state}
      {packet, state} -> {:reply, {state.status, packet}, state}
    end
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
  defp packet(%S{status: :done, buffer: buffer} = state) when byte_size(buffer) == 0 do
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
