defmodule Otis.Broadcaster.Bandwidth do
  def new(data_interval, data_size, window_size_s) do
    {{data_interval, data_size, window_size_s * 1000}, :queue.new, {0, nil}}
  end

  def sent({config, queue, stats}) do
    time = now
    stats = update_stats(stats, time)
    {config, :queue.snoc(queue, time), stats}
  end

  def stats({config, queue, stats}) do
    calculate_stats(stats, config, :queue.last(queue))
  end

  defp calculate_stats({count, s} = _stats, config, last) do
    # FIXME: take finish time from last item in queue
    {data_interval, data_size, window_size_ms} = config
    duration = last - s
    total_data = data_size * count
    bandwidth = 1000 * (total_data / duration)
    bandwidth
  end

  def update_stats({count, nil}, now) do
    {count + 1, now}
  end

  def update_stats({count, s}, now) do
    {count + 1, s}
  end

  def adjust({config, queue, stats} = bw, next_interval) do
    {data_interval, data_size, window_size_ms} = config
    events = :queue.to_list(queue)
    interval = next_interval
    if length(events) > 1 do
      target = target_bandwidth(config)
      first  = List.first(events)
      last   = List.last(events)
      finish = last - window_size_ms
      events = Enum.filter events, fn(e) -> e >= finish end
      sent_bytes = length(events) * data_size
      bandwidth = 1000 * (sent_bytes / (last - first))
      interval = case bandwidth / target do
        ratio when ratio < 1 ->
          next_interval - interval_increment(ratio, data_interval)
        ratio when ratio > 1 ->
          next_interval + interval_increment(ratio, data_interval)
        _ ->
          next_interval
      end
      # IO.inspect [:bandwidth, bandwidth, target, bandwidth/target, last - first, length(events), interval]
    end
    queue = :queue.from_list(events)
    {:ok, {config, queue, stats}, interval}
  end

  @doc """
  Gives a number of milliseconds to add/subtract to/from interval based on the
  current ratio of actual/target bandwidth.

  Because we can only alter the interval by 1 millisecond and this is too big a
  change to maintain a sufficiently accurate output rate we produce a
  fractional increment by using a random number to output the 1 millisecond
  change once every x cycles.
  """
  def interval_increment(ratio, data_interval) do
    diff = abs(1 - abs(ratio))
    percent_per_ms = 1/data_interval
    x = (diff/percent_per_ms)
    y = :random.uniform
    case y <= x do
      true  -> 1
      false -> 0
    end
  end

  def interval_increment(ratio, data_interval, too_low) do
    diff = abs(1 - abs(ratio))
    percent_per_ms = 1/data_interval
    x = (diff/percent_per_ms)
    y = :random.uniform
    case too_low do
      true ->
        case x do
          _ when y >= x -> 1
          _ -> 0
        end
      false ->
        case x do
          _ when y > x -> 1
          _ -> 0
        end
    end
  end

  def target_bandwidth({data_interval, data_size, window_size_ms}) do
    (1000 / data_interval) * data_size
  end

  def now do
    Otis.milliseconds
  end
end
