defmodule Otis.Pipeline.Hub do
  use GenServer
  @moduledoc """
  The interface between a playlist and the sources
  1. Takes a playlist
  2. Pops a rendition from the playlist
  3. Converts it to a source
  4. Opens the source
  5. Puts a transcoder in front of it
  6. Puts a buffer in front of the transcoder
  7. Returns packets from the current buffer to whoever wants them
  8. When a buffer informs us that it's source is done {:done, <<data>>} we do 2-6 to get the next stream
  9. When the current buffer returns :done we swap in our pending stream with the current one

  When we get a stop, we forward that onto the current stream
  When we get a skip we clear out our streams and start from scratch
  """

  alias Otis.Pipeline.Playlist
  alias Otis.Pipeline.Producer

  defmodule S do
    @moduledoc false
    defstruct [
      :playlist,
      :config,
      :transcoder_module,
      :rendition,
      :stream,
    ]
  end

  def start_link(playlist, config) do
    GenServer.start_link(__MODULE__, [playlist, config])
  end

  def skip(hub, rendition_id) do
    GenServer.call(hub, {:skip, rendition_id})
  end

  def pause(hub) do
    Producer.pause(hub)
  end

  def init([playlist, config]) do
    state = %S{
      playlist: playlist,
      config: config,
    } |> initialize()
    {:ok, state}
  end

  def handle_call(:next, _from, state) do
    {reply, state} = next_packet(state)
    {:reply, reply, state}
  end

  def handle_call({:skip, rendition_id}, _from, state) do
    Playlist.skip(state.playlist, rendition_id)
    {:reply, :ok, shutdown(state)}
  end

  def handle_call(:pause, _from, state) do
    {reply, state} = pause_stream(state)
    {:reply, reply, state}
  end

  defp pause_stream(%S{stream: nil} = state) do
    {:ok, state}
  end
  defp pause_stream(%S{stream: stream} = state) do
    pause_stream(state, Producer.pause(stream))
  end
  defp pause_stream(state, :ok) do
    {:ok, state}
  end
  defp pause_stream(%S{stream: stream} = state, :stop) do
    shutdown_producer(stream)
    {:stop, %S{state | stream: nil}}
  end

  defp shutdown(state) do
    shutdown_producer(state.stream)
    %S{state | stream: nil, rendition: nil}
  end

  defp shutdown_producer({stream, _rendition}) do
    shutdown_producer(stream)
  end
  defp shutdown_producer(nil) do
  end
  defp shutdown_producer(stream) do
    Producer.stop(stream)
  end

  defp initialize(state) do
    # TODO: replace :next with :current which returns either :active or the first
    case Playlist.next(state.playlist) do
      {:ok, rendition} ->
        {:ok, stream} = start_stream(rendition, state)
        %S{ state | stream: stream, rendition: rendition }
      :done ->
        state
    end
  end

  defp load_pending_stream(%S{stream: nil, rendition: rendition} = state) when not is_nil(rendition) do
    {:ok, stream} = start_stream(rendition, state)
    %S{state| stream: stream}
  end
  defp load_pending_stream(state) do
    case Playlist.next(state.playlist) do
      {:ok, rendition} ->
        {:ok, stream} = start_stream(rendition, state)
        append_stream(stream, rendition, state)
      :done ->
        state
    end
  end

  defp append_stream(stream, rendition, state) do
    %S{ state | stream: stream, rendition: rendition }
  end

  defp start_stream(rendition, state) do
    Otis.Pipeline.Streams.start_stream(rendition, state.config)
  end

  defp next_packet(%S{stream: nil} = state) do
    state |> load_pending_stream() |> next_packet(:done)
  end
  defp next_packet(state) do
    next_packet(state, :ok)
  end
  # Prevent infinite loops when coming from an expired stream + playlist
  defp next_packet(%S{stream: nil} = state, :done) do
    {:done, state}
  end
  defp next_packet(%S{stream: stream} = state, _) do
    stream |> Producer.next() |> handle_data(state)
  end

  defp handle_data({:ok, data}, state) do
    {{:ok, data}, state}
  end
  defp handle_data({:done, data}, state) do
    {{:ok, data}, state}
  end
  defp handle_data(:done, state) do
    %S{state | stream: nil, rendition: nil} |> load_pending_stream() |> next_packet(:done)
  end
end
