alias Experimental.{GenStage}

defmodule HLS.Client do
  defmodule Producer do
    use GenStage
    require Logger

    defmodule S do
      defstruct [
        :stream,
        :playlist,
        :opts,
        :reader,
        :url,
        :media,
        demand: 0,
        reload_at: 0,
        reloading: false,
      ]
    end

    def init([stream, reader, opts]) do
      {:producer, %S{stream: stream, reader: reader, opts: opts}}
    end

    def handle_demand(demand, %S{url: nil, stream: stream} = state) do
      playlist = HLS.Stream.resolve(stream, state.opts)
      state = %S{
        state |
        playlist: playlist,
        url: to_string(playlist.uri),
        media: playlist.media
      }
      schedule_reload(playlist)
      handle_demand(demand, state)
    end
    def handle_demand(demand, %S{media: []} = state) do
      {:noreply, [], %S{state | demand: demand}}
    end
    def handle_demand(demand, state) do
      {events, media} = Enum.split(state.media, demand)
      {:noreply, events, %S{state | media: media}}
    end

    def handle_cast({:bandwidth, times}, state) do
      # TODO: call upgrade/downgrade based on this download speed info
      average = Enum.reduce(times, 0, fn(p, sum) -> p + sum end) / length(times)
      Logger.info "=== Media load time #{ inspect 100 * Float.round(average, 2) }%"
      {:noreply, [], state}
    end

    def handle_cast({:data, :playlist, data}, state) do
      playlist = M3.Parser.parse!(data, state.url)
      {:ok, media} = M3.Playlist.sequence(playlist, state.playlist)
      Logger.info "New media #{length(media)}/#{state.demand} - #{playlist.media_sequence_number}"
      {events, media} = Enum.split(media, state.demand)
      state = %S{ state | playlist: playlist, media: media, demand: state.demand - length(events), reloading: false }
      {:noreply, events, state}
    end

    def handle_info(:reload, %S{reloading: true} = state) do
      schedule_reload(state.playlist)
      {:noreply, [], state}
    end
    def handle_info(:reload, %S{reloading: false} = state) do
      HLS.Reader.Worker.read(state.reader, state.url, self(), :playlist)
      schedule_reload(state.playlist)
      {:noreply, [], %S{state | reloading: true}}
    end

    defp schedule_reload(playlist) do
      wait = max(round(Float.floor(playlist.target_duration * 0.75)), 1)
      Process.send_after(self(), :reload, wait * 1000)
    end
  end

  defmodule ProducerConsumer do
    use GenStage

    def init([reader]) do
      {:producer_consumer, reader}
    end

    def handle_events(events, {producer, _ref} = _from, reader) do
      {times, data} =  Enum.map(events, fn(media) ->
        {t, data} = :timer.tc(fn ->
          HLS.Reader.read!(reader, media.url)
        end)
        {t / (media.duration * 1_000_000), data}
      end) |> Enum.unzip
      GenStage.cast(producer, {:bandwidth, times})
      {:noreply, data, reader}
    end
  end

  defmodule Consumer do
    use GenStage

    defmodule S do
      defstruct [
        packets: [],
        waiting: [],
      ]
    end

    def init(_stream) do
      {:consumer, %S{}}
    end

    def handle_events(events, _from, state) do
      state = reply(%S{ state | packets: state.packets ++ events})
      {:noreply, [], state}
    end

    def handle_call(:read, from, state) do
      state = reply(%S{ state | waiting: state.waiting ++ [from] })
      {:noreply, [], state}
    end

    defp reply(%S{ waiting: [] } = state) do
      state
    end
    defp reply(%S{ packets: [] } = state) do
      state
    end
    defp reply(%S{ waiting: [from | waiting], packets: [packet | packets] } = state) do
      GenStage.reply(from, {:ok, packet})
      reply(%S{ state | waiting: waiting, packets: packets })
    end
  end

  def start_link(stream, opts) do
    GenServer.start_link(__MODULE__, [stream, opts])
  end

  def init([stream, opts]) do
    {:ok, producer} = GenStage.start_link(HLS.Client.Producer, [stream, stream.reader, opts])
    {:ok, producer_consumer} = GenStage.start_link(HLS.Client.ProducerConsumer, [stream.reader])
    {:ok, consumer} = GenStage.start_link(HLS.Client.Consumer, stream)
    GenStage.sync_subscribe(producer_consumer, to: producer, max_demand: 1)
    GenStage.sync_subscribe(consumer, to: producer_consumer)
    {:ok, consumer}
    {:ok, consumer}
  end

  def handle_call(:consumer, _from, consumer) do
    {:reply, {:ok, consumer}, consumer}
  end

  def new!(stream, opts \\ [])
  def new!(stream, opts) do
    {:ok, pid, consumer} = new(stream, opts)
    {pid, consumer}
  end

  def new(stream, opts \\ [])
  def new(stream, opts) do
    {:ok, pid} = HLS.Client.Supervisor.start(stream, opts)
    {:ok, consumer} = GenServer.call(pid, :consumer)
    {:ok, pid, consumer}
  end


  def open!(stream, opts \\ [bandwidth: :highest])
  def open!(%HLS.Stream{} = stream, opts) do
    Elixir.Stream.resource(
      fn() -> new!(stream, opts) end,
      fn(client) -> read!(client) end,
      fn(client) -> close!(client) end
    )
  end

  def read!({_parent, consumer} = client) do
    {:ok, data} = GenStage.call(consumer, :read, 30_000)
    {[data], client}
  end

  def close!({parent, _} = client) do
    :ok = HLS.Client.Supervisor.stop(parent)
    {:ok, client}
  end
end
