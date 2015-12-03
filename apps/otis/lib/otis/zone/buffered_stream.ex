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
    :fetcher,
    :size,
    :waiting,
    :task,
    packets: 0,
    state: :waiting, # [:waiting, :playing, :stopped]
    queue: :queue.new
  ]

  alias __MODULE__, as: S

  def seconds(seconds, interval_ms \\ Otis.stream_interval_ms) do
    round((seconds * 1000) / interval_ms)
  end

  def start_link(source_stream, bytes_per_packet, size) do
    GenServer.start_link(__MODULE__, [source_stream, bytes_per_packet, size])
  end

  def init([source_stream, bytes_per_packet, size]) do
    {:ok, audio_stream } = Otis.AudioStream.start_link(source_stream, bytes_per_packet)
    pid = start_fetcher(audio_stream)
    {:ok, %S{audio_stream: audio_stream, fetcher: pid, size: size, packets: 0 }}
  end

  def start_fetcher(audio_stream) do
    pid = spawn(Otis.Zone.BufferedStream.Fetcher, :init, [audio_stream])
    Process.monitor(pid)
    pid
  end

  def handle_call(:frame, _from, %S{state: :stopped, packets: packets} = state) when packets == 0 do
    {:reply, :stopped, %S{state | state: :waiting}}
  end

  def handle_call(:frame, from, state) do
    state = pop(state, from)
    {:noreply, state}
  end

  def handle_call(:flush, _from, state) do
    Otis.Stream.flush(state.audio_stream)
    {:reply, :ok, %S{ state | queue: :queue.new, state: :waiting, packets: 0 }}
  end

  def handle_cast({:frame, frame}, state) do
    {:noreply, push(frame, state)}
  end

  def handle_cast({:rebuffer, packets}, state) do
    {:noreply, rebuffer_packets(packets, state)}
  end

  defp rebuffer_packets([], state) do
    state
  end
  defp rebuffer_packets([packet | packets], state) do
    rebuffer_packets(packets, unshift(packet, state))
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, %S{audio_stream: audio_stream} = state) do
    Logger.warn "#{__MODULE__} down, restarting..."
    {:noreply, %S{ state | fetcher: start_fetcher(audio_stream) }}
  end

  # No need to monitor this action as it's only called by the rebuffering
  defp unshift(packet, %S{queue: queue, packets: packets} = state) do
    queue = :queue.in_r(packet, queue)
    %S{ state | queue: queue, packets: packets + 1, state: :playing }
  end

  defp push({:ok, packet}, state) do
    push(packet, state)
  end
  defp push(packet, %S{queue: queue, packets: packets} = state) do
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

  # Uncomment the below if the desired behaviour is for the buffer to be full
  # before starting to play.
  defp monitor(%S{waiting: waiting, packets: packets, size: size} = state)
  when (not is_nil(waiting)) and (packets < size) do
    fetch_async(state)
  end

  defp monitor(%S{waiting: waiting} = state) do
    pop(%S{ state | waiting: nil }, waiting)
  end

  defp fetch_async(%{fetcher: fetcher} = state) do
    try do
      Kernel.send(fetcher, {:fetch, self})
    rescue
      error -> Logger.warn "Error triggering fetcher process #{ inspect error }"
    end
    state
  end

  # TODO: replace per-buffer fetcher process with a pool shared across zones
  # that way they have their own supervisor & we don't have to manage them in
  # this module.
  defmodule Fetcher do
    use     GenServer
    require Logger

    def init(stream) do
      Logger.debug "#{__MODULE__ } init..."
      loop(stream)
    end

    def loop(stream) do
      receive do
        {:fetch, from} -> fetch(from, stream)
        :exit          -> Logger.debug "Stopping #{__MODULE__}"
        msg            -> Logger.debug "#{__MODULE__} got msg #{ inspect msg }"
      end
    end

    def fetch(from, stream) do
      GenServer.cast(from, {:frame, Otis.AudioStream.frame(stream)})
      loop(stream)
    end
  end
end
