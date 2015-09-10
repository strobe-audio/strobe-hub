defmodule Janis.Monitor do
  use     GenServer
  alias   Janis.Monitor.Collector
  require Logger

  defmodule S do
    defstruct broadcaster: nil,
              delta: 0,
              latency: 0,
              measurement_count: 0,
              player: nil
  end

  @monitor_name Janis.Monitor

  def start_link(broadcaster) do
    GenServer.start_link(__MODULE__, broadcaster, name: @monitor_name)
  end

  def init(broadcaster)  do
    {:ok, collect_measurements(%S{broadcaster: broadcaster})}
  end

  def time_delta do
    GenServer.call(@monitor_name, :get_delta)
  end

  def handle_call({:sync, {originate_ts} = packet}, _from, state) do
    {:reply, {originate_ts, Janis.microseconds}, state}
  end

  def handle_call(:get_delta, _from, %S{delta: delta} = state) do
    {:reply, {:ok, delta}, state}
  end

  defp collect_measurements(%S{measurement_count: count, broadcaster: broadcaster} = state) do
    {interval, sample_size} = case count do
      # _ when count == 0  -> { 100, 31}
      _ when count == 0  -> { 100, 11} # debugging value -- saves me a bit of waiting
      _ when count  < 10 -> { 100, 11}
      _ when count >= 20 -> {1000, 11}
      _ when count >= 10 -> { 500, 11}
    end
    Collector.start_link(self, broadcaster, interval, sample_size)
    state
  end

  def handle_cast({:join_zone, {ip, port}, packet_interval, packet_size}, state) do
    Logger.info "Joining zone #{inspect {ip, port}} interval: #{packet_interval}ms; size: #{packet_size}bytes"
    {:ok, pid} = Janis.Player.Supervisor.start_link({ip, port}, {packet_interval, packet_size})
    {:noreply, %S{state | player: pid}}
  end

  def handle_cast({:append_measurement, {mlatency, mdelta}}, %S{measurement_count: measurement_count, latency: latency, delta: delta} = state) do
    # Logger.debug "New measurement, #{mlatency}, #{mdelta}"
    # calculate new delta & latency using Cumulative moving average, see:
    # https://en.wikipedia.org/wiki/Moving_average
    new_count = measurement_count + 1
    max_latency = case mlatency do
      _ when mlatency > latency -> mlatency
      _ -> latency
    end
    avg_delta = round (((measurement_count * delta) + mdelta) / new_count)
    state = %S{ state | measurement_count: new_count, latency: max_latency, delta: avg_delta }
    {:noreply, state |> update_measurements |> collect_measurements}
  end

  # FIXME: This should send the updated time offset & latency somewhere, but where?
  # The broadcaster needs the latency info but the player needs the time delta
  def update_measurements(%S{broadcaster: broadcaster, latency: latency, delta: delta} = state) do
    # Logger.debug "Update measurements latency: #{latency}us; delta: #{delta}us"
    GenServer.cast(broadcaster, {:receiver_latency, latency})
    state
  end

  defmodule Collector do
    require Logger

    def start_link(monitor, broadcaster, interval, count) do
      # Logger.debug "Starting new collector monitor: #{inspect monitor}; interval: #{interval}; count: #{count}"
      GenServer.start_link(__MODULE__, {monitor, broadcaster, interval, count})
    end

    def init({monitor, broadcaster, interval, count}) do
      # Logger.disable self
      Process.send_after(self, :measure, 1)
      {:ok, %{monitor: monitor, broadcaster: broadcaster, interval: interval, count: count, measurements: []}}
    end

    def handle_info(:measure, %{count: count, interval: interval} = state) when count > 0 do
      Process.send_after(self, :measure, interval)
      {:noreply, measure_sync(state)}
    end

    def handle_info(:measure, %{count: count, monitor: monitor} = state) when count <= 0 do
      {latency, delta} = calculate_sync(state)
      GenServer.cast(monitor, {:append_measurement, {latency, delta}})
      {:noreply, state}
    end

    defp measure_sync(%{measurements: measurements, count: count, broadcaster: broadcaster} = state) when count > 0  do
      {:ok, {start, receipt, reply, finish}} = sync_exchange(broadcaster)
      latency = (finish - start) / 2
      # https://en.wikipedia.org/wiki/Network_Time_Protocol#Clock_synchronization_algorithm
      delta = round(((receipt - start) + (reply - finish)) / 2)
      %{ state | count: count - 1,  measurements: [{latency, delta} | measurements]}
    end

    # http://www.mine-control.com/zack/timesync/timesync.html
    defp calculate_sync(%{measurements: measurements} = _state) do
      sorted_measurements = Enum.sort_by measurements, fn({latency, _delta}) -> latency end
      {:ok, median} = Enum.fetch sorted_measurements, round(Float.floor(length(measurements)/2))
      {median_latency, _} = median
      std_deviation = std_deviation(sorted_measurements, median_latency)
      discard_limit = median_latency + std_deviation
      valid_measurements = Enum.reject sorted_measurements, fn({latency, _delta}) -> latency > discard_limit end
      { max_latency, _delta } = Enum.max_by measurements, fn({latency, _delta}) -> latency end
      average_delta = Enum.reduce(valid_measurements, 0, fn({_latency, delta}, acc) -> acc + delta end) / length(valid_measurements)
      { round(max_latency), round(average_delta) }
    end

    defp std_deviation(measurements, median_latency) do
      variance = Enum.reduce(measurements, 0, fn({latency, _delta}, acc) ->
        acc + :math.pow(latency - median_latency, 2)
      end) / length(measurements)
      :math.sqrt(variance)
    end

    # defp get_sync(node, measurements, _latency, 0) do
    #   measurements
    # end

    defp sync_exchange(broadcaster) do
      GenServer.call(broadcaster, :measure_latency)
    end

    def terminate(reason, state) do
      Logger.debug "Monitor terminate #{inspect reason} #{inspect state}"
      :ok
    end
  end

end
