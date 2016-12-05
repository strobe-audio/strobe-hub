defmodule Otis.Channel.BufferedStream do
  @moduledoc """
  Sits between a channel broadcaster and the audio stream and buffers the audio
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
    buffering: false,
    state: :waiting, # [:waiting, :playing, :stopped]
    queue: :queue.new
  ]

  alias __MODULE__, as: S



# buffer_seconds, stream_bytes_per_step, interval_ms
  def start_link(id, config, audio_stream) do
    name = Otis.Stream.Supervisor.name(id)
    GenServer.start_link(__MODULE__, [id, config, audio_stream], name: name)
  end

  def init([id, config, {module, args}]) do
    {:ok, audio_stream } = apply(module, :start_link, args)
    init([id, config, audio_stream])
  end

  def init([_id, config, audio_stream]) when is_pid(audio_stream) do
    {:ok, fetcher} = start_fetcher(audio_stream)
    {:ok, %S{
      audio_stream: audio_stream,
      fetcher: fetcher,
      size: config.size,
      packets: 0
    }}
  end

  def start_fetcher(audio_stream) do
    pid = spawn(Otis.Channel.BufferedStream.Fetcher, :init, [audio_stream])
    Process.monitor(pid)
    {:ok, pid}
  end

  def handle_call(:buffer, from, state) do
    {:noreply, buffer(state, from)}
  end

  def handle_call(:frame, _from, %S{state: :stopped, packets: 0} = state) do
    {:reply, :stopped, state}
  end

  def handle_call(:frame, from, state) do
    state = pop(state, from)
    {:noreply, state}
  end

  def handle_call(:flush, _from, state) do
    Otis.Stream.flush(state.audio_stream)
    {:reply, :ok, _flush(state)}
  end

  def handle_call(:reset, _from, state) do
    Otis.Stream.reset(state.audio_stream)
    {:reply, :ok, change_state(state, :waiting)}
  end

  def handle_call(:resume, _from, state) do
    reply = Otis.Stream.resume(state.audio_stream)
    state = case reply do
      :resume -> state
      :flush -> _flush(state)
    end
    {:reply, reply, state}
  end

  def handle_cast({:push_frame, frame}, state) do
    {:noreply, push(frame, state)}
  end

  def handle_cast({:rebuffer, packets}, state) do
    {:noreply, rebuffer_packets(packets, state)}
  end

  def handle_cast({:skip, id}, state) do
    Otis.Stream.skip(state.audio_stream, id)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, fetcher, :normal}, %S{fetcher: fetcher, audio_stream: audio_stream} = state) do
    Logger.warn "#{__MODULE__} down, restarting..."
    {:noreply, %S{ state | fetcher: start_fetcher(audio_stream) }}
  end
  def handle_info({:DOWN, ref, process, pid, reason}, state) do
    IO.inspect [__MODULE__, :DOWN, ref, process, pid, reason]
    {:noreply, state}
  end
  def handle_info({:EXIT, pid, reason}, state) do
    IO.inspect [__MODULE__, :EXIT, pid, reason]
    {:noreply, state}
  end

  defp _flush(state) do
    %S{ change_state(state, :waiting) | queue: :queue.new, packets: 0 }
  end

  defp rebuffer_packets([], state) do
    state
  end
  defp rebuffer_packets([packet | packets], state) do
    rebuffer_packets(packets, unshift(packet, state))
  end

  # No need to monitor this action as it's only called by the rebuffering
  defp unshift(packet, %S{queue: queue, packets: packets} = state) do
    queue = :queue.in_r(packet, queue)
    %S{ state | queue: queue, packets: packets + 1 }
  end

  defp push(:stopped, %S{waiting: nil} = state) do
    change_state(state, :stopped)
  end
  defp push(:stopped, %S{waiting: waiting} = state) do
    pop(change_state(_push(:stopped, state), :stopped), waiting)
  end
  defp push({:ok, packet}, state) do
    push(packet, state)
  end
  defp push(packet, %S{ state: :playing } = state) do
    _push(packet, state) |> monitor
  end
  defp push(packet, state) do
    change_state(_push(packet, state), :playing) |> monitor
  end

  defp _push(packet, state) do
    %S{ state | queue: :queue.in(packet, state.queue), packets: state.packets + 1}
  end


  defp pop(%S{state: :stopped, packets: 0} = state, _from) do
    state
  end
  defp pop(%S{state: :stopped} = state, from) do
    _pop(state, from)
  end
  defp pop(%S{packets: 0} = state, from) do
    fetch_async(%S{ state | waiting: from })
  end
  defp pop(state, from) do
    _pop(state, from)
  end
  defp _pop(state, from) do
    queue = case :queue.out(state.queue) do
      {{:value, :stopped}, queue} ->
        GenServer.reply(from, :stopped)
        queue
      {{:value, packet}, queue} ->
        GenServer.reply(from, {:ok, packet})
        queue
      {:empty, queue} -> queue
    end
    %S{ state | queue: queue, packets: state.packets - 1 }
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

  # Uncomment the below if the desired behaviour is for the buffer to be full
  # before starting to play.
  defp monitor(%S{waiting: waiting, packets: packets, size: size} = state)
  when (not is_nil(waiting)) and (packets < size) do
    fetch_async(state)
  end
  # unlikely - nothing waiting and we have exactly the right number of packets
  defp monitor(%S{waiting: nil} = state) do
    state
  end
  defp monitor(%S{waiting: waiting, buffering: true} = state) do
    buffered(%S{ state | waiting: nil }, waiting)
  end
  defp monitor(%S{waiting: waiting} = state) do
    pop(%S{ state | waiting: nil }, waiting)
  end

  defp buffer(%S{packets: packets, size: size} = state, from)
  when (packets < size) do
    fetch_async(%S{ state | waiting: from, buffering: true })
  end

  defp buffer(state, from) do
    buffered(state, from)
  end

  defp buffered(state, from) do
    GenServer.reply(from, :ok)
    %S{state | buffering: false}
  end

  defp fetch_async(%{fetcher: fetcher} = state) do
    try do
      Kernel.send(fetcher, {:fetch, self()})
    rescue
      error -> Logger.warn "Error triggering fetcher process #{ inspect error }"
    end
    state
  end

  defp change_state(stream, state) do
    %S{ stream | state: state}
  end

  # TODO: replace per-buffer fetcher process with a pool shared across channels
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
      GenServer.cast(from, {:push_frame, Otis.AudioStream.frame(stream)})
      loop(stream)
    end
  end
end
