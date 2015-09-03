defmodule Otis.Receiver.Monitor do
  use GenServer
  require Logger
  alias Otis.Receiver.Monitor.Collector

  defmodule S do
    defstruct receiver: nil, receiver_node: nil, delta: 0, latency: 0, measurement_count: 0
  end

  def start_link(receiver, receiver_node) do
    GenServer.start_link(__MODULE__, [receiver, receiver_node])
  end

  def init([receiver, receiver_node])  do
    # Logger.disable self
    Logger.debug "Starting monitor for #{receiver} node: #{inspect receiver_node}"
    {:ok, collect_measurements(%S{receiver: receiver, receiver_node: receiver_node})}
  end

  def handle_cast({:append_measurement, {mlatency, mdelta}}, %S{measurement_count: measurement_count, latency: latency, delta: delta} = state) do
    # calculate new delta & latency using Cumulative moving average, see:
    # https://en.wikipedia.org/wiki/Moving_average
    new_count = measurement_count + 1
    max_latency = case mlatency do
      _ when mlatency > latency -> mlatency
      _ -> latency
    end
    avg_delta = round (((measurement_count * delta) + mdelta) / new_count)
    state = %S{ state | measurement_count: new_count, latency: max_latency, delta: avg_delta }
    {:noreply, state |> update_receiver |> collect_measurements}
  end

  def update_receiver(%S{receiver: receiver, delta: delta, latency: latency} = state) do
    # Logger.debug "Update receiver #{inspect receiver}"
    GenServer.cast(receiver, {:update_synchronisation, latency, delta})
    state
  end

  def collect_measurements(%S{measurement_count: count, receiver_node: receiver_node} = state) when count == 0 do
    Collector.start_link(self, receiver_node, 100, 31)
    state
  end

  def collect_measurements(%S{measurement_count: count, receiver_node: receiver_node} = state) when count >= 20 do
    Collector.start_link(self, receiver_node, 1000, 11)
    state
  end

  def collect_measurements(%S{measurement_count: count, receiver_node: receiver_node} = state) when count >= 10 do
    Collector.start_link(self, receiver_node, 500, 11)
    state
  end

  def collect_measurements(%S{measurement_count: count, receiver_node: receiver_node} = state) when count < 10 do
    Collector.start_link(self, receiver_node, 100, 11)
    state
  end

  defmodule Collector do
    require Logger

    def start_link(monitor, receiver_node, interval, count) do
      # Logger.debug "Starting new collector interval: #{interval}; count: #{count}"
      GenServer.start_link(__MODULE__, [monitor, receiver_node, interval, count])
    end

    def init([monitor, receiver_node, interval, count]) do
      # Logger.disable self
      Process.send_after(self, :measure, 1)
      {:ok, %{monitor: monitor, receiver_node: receiver_node, interval: interval, count: count, measurements: []}}
    end

    def terminate(reason, state) do
      Logger.debug "Monitor terminate #{inspect reason} #{inspect state}"
      :ok
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

    defp measure_sync(%{measurements: measurements, count: count, receiver_node: receiver} = state) when count > 0  do
      start = Otis.microseconds
      {_, receipt} = sync_exchange(receiver, start)
      finish = Otis.microseconds
      latency = (finish - start) / 2
      # https://en.wikipedia.org/wiki/Network_Time_Protocol#Clock_synchronization_algorithm
      delta = round(((receipt - start) + (receipt - finish)) / 2)
      %{ state | count: count - 1,  measurements: [{latency, delta} | measurements]}
    end

    # defp calculate_sync(receiver_node) do
    #   # Setup the connection
    #   {_, receipt} = sync_exchange(receiver_node)
    #   { delay, diff } = measure_sync(receiver_node)
    #   {diff, delay}
    #   # %S{ state | time_diff: diff, delay: delay }
    # end

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

    defp sync_exchange(node, start) do
      GenServer.call({Janis.Monitor, node}, {:sync, {start}})
      # case GenServer.call({Janis.Monitor, node}, {:sync, {start}}) do
      #   # {:ok, _} = _result ->
      #     # :ok
      #   {:error} = _error ->
      #     Logger.warn "Node down #{inspect _error}"
      #     _error
      # end
      # try do
      # rescue
      #   e in [ErlangError] ->
      # # catch
      # #   _ = e -> Logger.warn "Node down #{inspect e}"
      #
      # end
    end
  end
end

