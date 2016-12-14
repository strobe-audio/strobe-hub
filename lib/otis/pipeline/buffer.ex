defmodule Otis.Pipeline.Buffer do
  use GenServer

  alias Otis.State.Rendition
  alias Otis.Library.Source

  alias Otis.Pipeline.Producer
  alias Otis.Packet

  require Logger

  defmodule S do
    defstruct [
      :id,
      :config,
      :packet_size,
      :buffer_size,
      :packet_duration_ms,
      :stream,
      :source,
      start_position: 0,
      n: 0,
      status: :ok,
      empty: false,
      buffer: <<>>,
    ]
  end

  def start_link(name, rendition, config) do
    GenServer.start_link(__MODULE__, [rendition, config], [name: name])
  end

  def init([rendition, config]) do
    # Start our stream after returning from this init call so that our parent
    # isn't tied up waiting for sources to open
    GenServer.cast(self(), {:init, rendition.id})
    {:ok, %S{
      id: rendition.id,
      config: config,
      packet_size: config.packet_size,
      buffer_size: (config.buffer_packets * config.packet_size),
      packet_duration_ms: config.packet_duration_ms,
    }}
  end

  def handle_cast({:init, rendition_id}, state) do
    state = rendition_id |> Rendition.find() |> start_stream(rendition_id, state)
    {:noreply, state}
  end

  def handle_call(:stop, _from, state) do
    {:stop, {:shutdown, :normal}, :ok, state}
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
  def handle_call(:pause, _from, state) do
    reply = Source.pause(state.source, state.id, state.stream)
    {:reply, reply, state}
  end

  def start_stream(nil, rendition_id, state) do
    Logger.warn("Rendition #{rendition_id} not found")
    state
  end
  def start_stream(rendition, rendition_id, state) do
    source = Rendition.source(rendition)
    stream = Source.open!(source, rendition_id, state.packet_size)
    {:ok, transcoder} = transcoder(state, rendition, source, stream)
    %S{ state | source: source, stream: transcoder, start_position: rendition.playback_position }
  end

  defp transcoder(state, rendition, source, stream) do
    Kernel.apply(state.config.transcoder, :start_link, [source, stream, rendition.playback_position, state.config])
  end

  def next_packet(%S{stream: nil} = state) do
    {:done, state}
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
      rendition_id: state.id,
      source_index: state.n,
      offset_ms: state.start_position + (state.n * state.packet_duration_ms),
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
