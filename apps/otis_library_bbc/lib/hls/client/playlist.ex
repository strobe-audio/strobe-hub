defmodule HLS.Client.Playlist do
  alias   Experimental.{GenStage}
  require Logger

  use     GenStage

  defmodule S do
    defstruct [
      :stream, :opts,
      :playlist,
      :reader,
      :url,
      media: [],
      demand: 0,
      reloading: false,
    ]
  end

  def init([stream, reader, opts]) do
    {:producer, %S{stream: stream, reader: reader, opts: opts}}
  end

  def handle_demand(demand, %S{url: nil, stream: stream} = state) do
    playlist = HLS.Stream.resolve(stream, state.opts)
    state = %S{
      state | playlist: playlist, url: to_string(playlist.uri), media: playlist.media
    }
    handle_demand(demand, state)
  end
  def handle_demand(demand, %S{media: []} = state) do
    {:noreply, [], reload(%S{state | demand: demand})}
  end
  def handle_demand(demand, state) do
    {events, media} = Enum.split(state.media, demand)
    {:noreply, events, %S{state | media: media}}
  end

  def handle_cast(:upgrade, state) do
    # TODO: call Stream.upgrade
    {:noreply, [], state}
  end
  def handle_cast(:downgrade, state) do
    # TODO: call Stream.downgrade
    {:noreply, [], state}
  end

  def handle_info(:reload, state) do
    {:noreply, [], read(state)}
  end

  def handle_info({:data, :playlist, {data, expiry}}, state) do
    playlist = M3.Parser.parse!(data, state.url)
    {:ok, media} = M3.Playlist.sequence(playlist, state.playlist)
    handle_media(media, expiry, %S{state | playlist: playlist, reloading: false})
  end

  defp handle_media([], _expiry, %S{demand: 0} = state) do
    {:noreply, [], state}
  end
  defp handle_media([], expiry, state) do
    {:noreply, [], reload(state, expiry)}
  end
  defp handle_media(media, _expiry, state) do
    # Logger.info "New media #{length(media)}/#{state.demand} - #{state.playlist.media_sequence_number}"
    {events, media} = Enum.split(media, state.demand)
    state = %S{ state | media: media, demand: state.demand - length(events) }
    {:noreply, events, state}
  end

  defp reload(%S{reloading: true} = state) do
    state
  end
  defp reload(%S{reloading: false} = state) do
    read(state)
  end
  defp reload(%S{reloading: true} = state, _wait) do
    state
  end
  defp reload(%S{reloading: false} = state, wait) do
    read(state, wait)
  end

  defp read(state) do
    HLS.Reader.Async.read_with_expiry(state.reader, state.url, self(), :playlist)
    %S{state | reloading: true}
  end

  defp read(state, seconds) do
    Process.send_after(self(), :reload, seconds * 1000)
    %S{state | reloading: true}
  end
end
