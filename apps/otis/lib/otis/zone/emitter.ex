
defmodule Otis.Zone.Emitter do
  @moduledoc """
  Emits a given audio packet ({timestamp, data}) at the given time
  """

  require Logger

  # Public API

  def emit(emitter, timestamp, packet, socket) do
    send(emitter, {:emit, timestamp, packet, socket})
  end

  ## GenServer api

  def start_link(opts) do
    :proc_lib.start_link(__MODULE__, :init, [opts])
  end

  @blank_emit {nil, nil, nil} # timestamp, packet, socket

  def init([interval: packet_interval, packet_size: packet_size, pool: pool] = opts) do
    Logger.disable self
    Logger.debug "Launched emitter #{inspect opts}"
    :proc_lib.init_ack({:ok, self})

    state = {
      {0, 0, 3000},                        # timing information
      @blank_emit,                         # emit data
      {packet_interval, packet_size, pool} # config
    }
    wait(state)
  end

  defp wait(state) do
    # Logger.debug "Emitter.wait... #{inspect state}"
    receive do
      {:emit, time, packet, socket} ->
        start(time, packet, socket, state)
      msg ->
        Logger.debug "Emitter got #{inspect msg}"
        wait(state)
    end
  end

  defp start(time, packet, socket, {{t, n, d}, _emit, _config} = state) do
    # Logger.disable(self)
    now = current_time
    {t, _} = packet
    case time - now do
      s when s < 0 ->
        Logger.warn "Start emitter:: emit time: #{s}; packet timestamp: #{t - now}"
      s ->
        Logger.debug "Start emitter:: emit time: #{s}; packet timestamp: #{t - now}"
    end
    state = {{current_time, n, d}, {time, packet, socket}, _config}
    test_packet state
  end

  defp loop(state) do
    receive do
    after 2 ->
      test_packet new_state(state)
    end
  end

  defp test_packet({{now, _, d}, {time, _packet, _socket}, _config} = state) do
    case time - now do
      x when x <= 1 ->
        emit_frame(state)
      x when x <= d ->
        loop_tight(state)
      _ ->
        loop(state)
    end
  end

  @jitter 500

  defp loop_tight({{t, n, d}, {time, _packet, _socket} = _emit, _config}) do
    now   = current_time
    state = {{now, n, d}, _emit, _config}
    case time - now do
      x when x <= @jitter ->
        emit_frame(state)
      _ -> loop_tight(state)
    end
  end

  defp emit_frame({_loop, {_time, {timestamp, data} = packet, socket}, {_pi, _ps, pool} = _config} = _state) do
    now = current_time
    Logger.debug "At #{_time - now}: emit #{timestamp - now} on socket #{inspect socket}"
    Otis.Zone.Socket.send(socket, timestamp, data)

    Logger.debug "Check back into pool #{pool}"
    :poolboy.checkin(pool, self)
    wait({_loop, @blank_emit, _config})
  end

  defp new_state({{t, n, d}, _emit, _config}) do
    m   = n+1
    now = current_time
    delay = case d do
      0 -> now - t
      _ -> (((n * d) + (now - t)) / m)
    end
    # if rem(m, 1000) == 0 do
    #   Logger.debug "#{now}, #{m}, #{delay}"
    # end
    {{now, m, delay}, _emit, _config}
  end

  defp current_time do
    Otis.microseconds
  end
end

