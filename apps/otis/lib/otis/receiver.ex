defmodule Otis.Receiver do
  use GenServer

  defmodule S do
    defstruct id: "receiver-1", name: "Receiver", node: nil, time_diff: 0, delay: 0
  end

  def start_link(id, node) do
    GenServer.start_link(__MODULE__, %S{id: id, node: node})
  end

  def init(state) do
    state = calculate_sync(state)
    IO.inspect state
    {:ok, state}
  end
  #
  # def init(%S{node: node} = receiver) do
  #   IO.inspect [:init, node, self]
  #   Process.flag(:trap_exit, true)
  #   Process.link(node)
  #   {:ok, receiver}
  # end

  defp calculate_sync(%S{node: node} = state) do
    # Setup the connection
    {_, receipt} = sync_exchange(node)
    { delay, diff } = measure_sync(node)
    %S{ state | time_diff: diff, delay: delay }
  end

  # http://www.mine-control.com/zack/timesync/timesync.html
  defp measure_sync(node) do
    measurements = get_sync(node, [], 200, 11)
    sorted_measurements = Enum.sort_by measurements, fn({delay, _diff}) -> delay end
    {:ok, median} = Enum.fetch sorted_measurements, round(Float.floor(length(measurements)/2))
    {median_delay, _} = median
    variance = Enum.reduce(sorted_measurements, 0, fn({delay, _diff}, acc) -> acc + :math.pow(delay - median_delay, 2) end) / length(sorted_measurements)
    std_deviation = :math.sqrt(variance)
    discard_limit = median_delay + std_deviation
    valid_measurements = Enum.reject sorted_measurements, fn({delay, _diff}) -> delay > discard_limit end
    { max_delay, _diff } = Enum.max_by valid_measurements, fn({delay, _diff}) -> delay end
    average_diff = Enum.reduce(valid_measurements, 0, fn({_delay, diff}, acc) -> acc + diff end) / length(valid_measurements)
    IO.inspect { round(max_delay), round(average_diff) }
  end


  defp get_sync(node, measurements, wait, count) when count > 0  do
    start = Otis.microseconds
    {_, receipt} = sync_exchange(node, start)
    finish = Otis.microseconds
    delay = (finish - start) / 2
    # https://en.wikipedia.org/wiki/Network_Time_Protocol#Clock_synchronization_algorithm
    diff = round(((receipt - start) + (receipt - finish)) / 2)
    # start + delay = receipt + diff
    # diff = round(receipt - finish + delay)
    :timer.sleep(wait)
    get_sync(node, [{delay, diff} | measurements], wait, count - 1)
  end

  defp get_sync(node, measurements, _delay, 0) do
    measurements
  end

  defp sync_exchange(node, start \\ Otis.microseconds) do
    {_, receipt} = GenServer.call({Janis.Monitor, node}, {:sync, {start}})
  end

  def id(pid) do
    GenServer.call(pid, :id)
  end

  def delay(pid) do
    GenServer.call(pid, :get_delay)
  end

  def receive_frame(pid, data, timestamp) do
    GenServer.cast(pid, {:receive_frame, data, timestamp})
  end


  def handle_call(:id, _from, %S{id: id} = receiver) do
    {:reply, {:ok, id}, receiver}
  end

  def handle_call(:get_delay, _from, %S{delay: delay} = receiver) do
    {:reply, {:ok, delay}, receiver}
  end

  def handle_cast({:receive_frame, data, timestamp}, %S{node: node} = rec) do
    # send(conn, {:audio_frame, data})
    GenServer.cast({Janis.Player, node}, {:play, data, receiver_timestamp(rec, timestamp)})
    {:noreply, rec}
  end

  def receiver_timestamp(%S{time_diff: time_diff} = _rec, player_timestamp) do
    player_timestamp + time_diff
  end

  # def terminate(reason, receiver) do
  #   IO.inspect [:receiver_terminate, reason]
  #   # Otis.Receivers.remove(Otis.Receivers, self)
  #   :ok
  # end
end
