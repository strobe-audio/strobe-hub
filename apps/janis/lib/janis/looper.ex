
defmodule Janis.Looper do
  require Logger

  def start_link(buffer, interval, _size) do
    :proc_lib.start_link(__MODULE__, :init, [self, buffer, interval, Janis.Looper, []])
  end

  def init(player, buffer, interval, name, opts) do
    Logger.debug "starting looper with interval #{interval}"
    :erlang.register(name, self)
    Process.flag(:trap_exit, true)
    :proc_lib.init_ack({:ok, self})
    state = next_frame({Janis.milliseconds, 0, 0, nil, <<>>, buffer, player})
    loop(state)
  end

  def random_timestamp(time \\ 20) do
    Janis.milliseconds + time#(time/2) + (round(:random.uniform * (time/2)))
  end

  def loop(state) do
    receive do
    after 2 ->
      {now, _, d, timestamp, _data, _buffer, _player} = state = new_state(state)
      case timestamp - now do
        x when x <= 1 ->
          play_frame(state)
        x when x <= d ->
          loop_tight(state)
        _ ->
          loop(state)
      end
    end
  end

  @jitter 1

  def loop_tight({t, n, d, timestamp, _data, _buffer, _player}) do
    now = Janis.milliseconds
    state = {now, n, d, timestamp, _data, _buffer, _player}
    case timestamp - now do
      x when x <= @jitter ->
        play_frame(state)
        # assuming that the interval between frames > 1ms
        # loop(next_frame(state))
      _ -> loop_tight(state)
    end
  end

  def play_frame({_t, _n, _d, timestamp, data, _buffer, player} = state) do
    # Logger.debug "Play frame.."
    send_data = case Janis.milliseconds - timestamp do
      d when d <= 0 -> data
      d ->
        # do I skip from the beginning or the end...
        Logger.warn "Late #{d} skipping #{skip_bytes(d)} bytes"
        case skip_bytes(d) do
          s when s > byte_size(data) ->
            <<>>
          s ->
            << skip :: binary-size(s), rest :: binary >> = data
            rest
        end
    end

    if byte_size(send_data) > 0 do
      GenServer.cast(player, {:play, send_data})
    end

    loop(next_frame(state))
  end

  # One frame is 16 bits over 2 channels
  @bytes_per_frame 2 * 2
  @frames_per_ms 44100 / 1000

  def skip_bytes(ms) do
    round(Float.ceil(@frames_per_ms * ms)) * @bytes_per_frame
  end

  def next_frame({t, n, d, _timestamp, _data, buffer, player}) do
    {:ok, {timestamp, data}} = Janis.Player.Buffer.get(buffer)
    {:ok, delta} = Janis.Monitor.time_delta
    time = round((timestamp - delta)/1000)
    now = Janis.milliseconds
    # Logger.debug "next_frame #{inspect time} #{time - now}"
    {t, n+1, d, time, data, buffer, player}
  end


  def new_state_tight({t, n, d, timestamp, data, buffer, _player}) do
    {Janis.milliseconds, n, d, timestamp, data, buffer, _player}
  end

  def new_state({t, n, d, timestamp, data, buffer, _player}) do
    m = n+1
    now = Janis.milliseconds
    delay = case d do
      0 -> now - t
      _ -> (((n * d) + (now - t)) / m)# |> Float.ceil# |> round
    end
    if rem(m, 1000) == 0 do
      # Logger.debug "#{now}, #{m}, #{delay}"
    end
    {now, m, delay, timestamp, data, buffer, _player}
  end
end
