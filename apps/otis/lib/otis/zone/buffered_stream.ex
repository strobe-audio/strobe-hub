defmodule Otis.Zone.BufferedStream do
  @moduledoc """
  Sits between a zone broadcaster and the audio stream and buffers the audio
  packets to protect against temporary slow-downs caused by delayed file opening
  and transcoder startup.
  """

  use     GenServer
  require Logger

  defstruct [
    :audio_stream,
    :size,
    :waiting,
    :task,
    packets: 0,
    state: :waiting, # [:waiting, :playing, :stopped]
    queue: :queue.new
  ]

  alias __MODULE__, as: S

  def start_link(source_stream, bytes_per_packet, size) do
    GenServer.start_link(__MODULE__, [source_stream, bytes_per_packet, size])
  end

  def init([source_stream, bytes_per_packet, size]) do
    {:ok, audio_stream } = Otis.AudioStream.start_link(source_stream, bytes_per_packet)
    {:ok, %S{audio_stream: audio_stream, size: size, packets: 0 }}
  end

  def handle_call(:frame, _from, %S{state: :stopped, packets: packets} = state) when packets == 0 do
    {:reply, :stopped, %S{state | state: :waiting}}
  end

  def handle_call(:frame, from, state) do
    state = pop(state, from)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({ref, result}, state) when is_reference(ref) do
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
    fetch_async(%S{ state | waiting: from })
  end

  defp pop(%S{packets: packets, queue: queue} = state, from) do
    {{:value, packet}, queue} = :queue.out(queue)
    GenServer.reply(from, {:ok, packet})
    monitor(%S{ state | queue: queue, packets: packets - 1})
  end

  defp monitor(%S{state: :stopped} = state) do
    state
  end

  defp monitor(%S{waiting: nil, packets: packets, size: size} = state) when packets < size do
    case size - packets do
      1 -> nil
      _ -> Logger.warn "#{__MODULE__} #{packets}/#{size}"
    end
    fetch_async(state)
  end

  # unlikely - nothing waiting and we have exactly the right number of packets
  defp monitor(%S{waiting: nil} = state) do
    state
  end

  defp monitor(%S{waiting: waiting, packets: packets, size: size} = state) when (not is_nil(waiting)) and (packets < size) do
    fetch_async(state)
  end

  defp monitor(%S{waiting: waiting} = state) do
    pop(%S{ state | waiting: nil }, waiting)
  end

  defp fetch_async(state) do
    %Task{pid: _pid, ref: _ref} = Task.async(__MODULE__, :fetch, [state])
    state
  end

  def fetch(%S{audio_stream: stream}) do
    Otis.AudioStream.frame(stream)
  end
end

