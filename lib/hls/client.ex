
defmodule HLS.Client do
  alias Experimental.{GenStage}
  use   GenStage

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
    GenStage.cast(producer, {:bandwidth, times})
    {:noreply, data, reader}
  end
end
