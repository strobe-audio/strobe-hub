
defmodule HLS.Client do
  alias   Experimental.{GenStage}
	require Logger

  use     GenStage

  def open!(stream, opts \\ [bandwidth: :highest])
  def open!(%HLS.Stream{} = stream, opts) do
    stream(stream, opts)
  end

  defp stream(stream, opts) do
    {:ok, pid} = HLS.Client.Supervisor.start(stream, opts)
    GenStage.stream([pid])
  end

  def start_link(stream, opts) do
    GenStage.start_link(__MODULE__, [stream, opts])
  end

  # Callbacks

  def init([stream, opts]) do
    {:ok, producer} = GenStage.start_link(HLS.Client.Playlist, [stream, stream.reader, opts])
    {:producer_consumer, stream.reader, subscribe_to: [{producer, [max_demand: 1]}]}
  end

  def handle_events(events, {producer, _ref} = _from, reader) do
    {times, data} = Enum.map(events, fn(media) ->
      {t, data} = :timer.tc(fn ->
        HLS.Reader.read!(reader, media.url)
      end)
      {t / (media.duration * 1_000_000), data}
    end) |> Enum.unzip
		monitor_bandwidth(producer, times)
    {:noreply, data, reader}
  end

	# TODO: upgrade/downgrade stream based on load times
	# GenStage.cast(producer, :downgrade)
	# GenStage.cast(producer, :upgrade)
	defp monitor_bandwidth(_producer, times) do
    average = Enum.reduce(times, 0, fn(p, sum) -> p + sum end) / length(times)
    Logger.info "=== Media load time #{ inspect 100 * Float.round(average, 2) }%"
	end
end
