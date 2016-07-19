
defmodule HLS.Client.Playlist do
  alias   Experimental.{GenStage}
  use     GenStage
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
      reloading: false,
    ]
  end

  def init([stream, reader, opts]) do
    {:producer, %S{stream: stream, reader: reader, opts: opts}}
  end

  def handle_subscribe(_stage, _opts, _to_or_from, state) do
    {:automatic, state}
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
