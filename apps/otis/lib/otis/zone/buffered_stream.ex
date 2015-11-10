defmodule Otis.Zone.BufferedStream do
  use     GenServer
  require Logger

  @name __MODULE__

  defstruct [:audio_stream, :size, :waiting, :task, packets: 0, state: :starting, queue: :queue.new]

  alias __MODULE__, as: S

  def start_link(source_stream, bytes_per_packet, size) do
    GenServer.start_link(__MODULE__, [source_stream, bytes_per_packet, size])
  end

  def init([source_stream, bytes_per_packet, size]) do
    Logger.info "#{__MODULE__} starting..."
    {:ok, audio_stream } = Otis.AudioStream.start_link(source_stream, bytes_per_packet)
    state = %S{audio_stream: audio_stream, size: size, packets: 0 }
    {:ok, state}
  end

  def handle_call(:frame, _from, %S{state: :stopped, packets: packets} = state) when packets == 0 do
    {:reply, :stopped, %S{state | state: :starting}}
  end

  def handle_call(:frame, from, %S{packets: packets, size: size} = state) do
    state = pop(state, from)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({_ref, result}, state) when is_reference(_ref) do
    state = push(result, state)
    {:noreply, state}
  end

  defp push({:ok, packet}, %S{queue: queue, packets: packets} = state) do
    queue = :queue.in(packet, queue)
    %S{ state | queue: queue, packets: packets + 1, state: :playing } |> monitor
  end

  defp push(:stopped, state) do
    %S{ state | state: :stopped }
  end

  defp pop(%S{packets: packets} = state, from) when packets == 0 do
    state = fetch_async(%S{ state | waiting: from })
  end

  defp pop(%S{packets: packets, queue: queue} = state, from) do
    {{:value, packet}, queue} = :queue.out(queue)
    state = monitor %S{ state | queue: queue, packets: packets - 1}
    GenServer.reply(from, {:ok, packet})
    state
  end

  defp monitor(%S{state: :stopped} = state) do
    state
  end

  defp monitor(%S{waiting: nil, packets: packets, size: size} = state) when packets < size do
    Logger.debug "#{__MODULE__} #{packets}"
    fetch_async(state)
  end

  defp monitor(%S{waiting: nil, packets: packets, size: size} = state) when packets < size do
    Logger.debug "#{__MODULE__} #{packets}"
    fetch_async(state)
  # unlikely - nothing waiting and we have exactly the right number of packets
  defp monitor(%S{waiting: nil} = state) do
    state
  end

  defp monitor(%S{waiting: waiting, packets: packets, size: size} = state) when (not is_nil(waiting)) and (packets < size) do
    fetch_async(state)
  end

  defp monitor(%S{waiting: waiting, packets: packets} = state) do
    pop(%S{ state | waiting: nil }, waiting)
  end

  defp fetch_async(state) do
    %Task{pid: _pid, ref: _ref} = Task.async(__MODULE__, :fetch, [state])
    state
  end

  def fetch(%S{audio_stream: stream} = state) do
    Otis.AudioStream.frame(stream)
  end
end

