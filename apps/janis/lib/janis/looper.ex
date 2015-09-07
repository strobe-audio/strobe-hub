
defmodule Janis.Looper do
  require Logger

  def start_link do
    :proc_lib.start_link(__MODULE__, :init, [self, Janis.Looper, []])
  end

  def init(parent, name, opts) do
    :erlang.register(name, self)
    Process.flag(:trap_exit, true)
    :proc_lib.init_ack({:ok, self})
    loop({Janis.milliseconds, 0, 0, random_timestamp})
  end

  def random_timestamp(time \\ 20) do
    Janis.milliseconds + time#(time/2) + (round(:random.uniform * (time/2)))
  end

  def loop(state) do
    receive do
    after 2 ->
      {now, _, d, timestamp} = state = new_state(state)
      case timestamp - now do
        x when x <= 1 ->
          play_frame(state)
        x when x <= d+1 ->
          loop_tight(state)
        _ ->
          loop(state)
      end
    end
  end

  @jitter 2

  def loop_tight({t, n, d, timestamp}) do
    {now, _, _, _} = state = {Janis.milliseconds, n, d, timestamp}
    case timestamp - now do
      x when x <= @jitter ->
        play_frame(state)
        # assuming that the interval between frames > 1ms
        # loop(next_frame(state))
      _ -> loop_tight(state)
    end
  end

  def play_frame({t, n, d, timestamp} = state) do
    case Janis.milliseconds - timestamp do
      d when d <= 0 -> :ok
      d ->
        # do I skip from the beginning or the end...
        Logger.debug "Late #{d} skipping #{skip_bytes(d)} bytes"
    end
    loop(next_frame(state))
  end

  # One frame is 16 bits over 2 channels
  @bytes_per_frame 2 * 2
  @frames_per_ms 44100 / 1000

  def skip_bytes(ms) do
    round(Float.ceil(@frames_per_ms * ms)) * @bytes_per_frame
  end

  def next_frame({t, n, d, _timestamp}) do
    # Call to the stream receiver to get next frame timestamp & data
    {t, n+1, d, random_timestamp}
  end

  def new_state_tight({t, n, d, timestamp}) do
    {Janis.milliseconds, n, d, timestamp}
  end

  def new_state({t, n, d, timestamp}) do
    m = n+1
    now = Janis.milliseconds
    delay = case d do
      0 -> now - t
      _ -> (((n * d) + (now - t)) / m)# |> Float.ceil# |> round
    end
    if rem(m, 1000) == 0 do
      Logger.debug "#{now}, #{m}, #{delay}"
    end
    {now, m, delay, timestamp}
  end
end
