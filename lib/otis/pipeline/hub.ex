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
  alias Otis.Pipeline.Transcoder
  alias Otis.Pipeline.Producer

  defmodule S do
    @moduledoc false
    defstruct [
      :playlist,
      :config,
      :transcoder_module,
      :stream,
      pending: :queue.new(),
    ]
  end

  def start_link(playlist, config, transcoder_module \\ Transcoder) do
    GenServer.start_link(__MODULE__, [playlist, config, transcoder_module])
  end

  def init([playlist, config, transcoder_module]) do
    state = %S{
      playlist: playlist,
      config: config,
      transcoder_module: transcoder_module,
    } |> initialize()
    {:ok, state}
  end

  def handle_call(:next, _from, state) do
    {reply, state} = next_packet(state)
    {:reply, reply, state}
  end

  defp initialize(state) do
    # TODO: replace :next with :current which returns either :active or the first
    {:ok, rendition} = Playlist.next(state.playlist)
    {:ok, stream} = start_stream(rendition, state)
    %S{ state | stream: stream }
  end

  defp load_pending_stream(state) do
    case Playlist.next(state.playlist) do
      {:ok, rendition} ->
        {:ok, stream} = start_stream(rendition, state)
        append_stream(stream, state)
      :done ->
        state
    end
  end

  defp append_stream(stream, %S{stream: nil} = state) do
    %S{ state | stream: stream }
  end
  defp append_stream(stream, state) do
    %S{ state | pending: :queue.in(stream, state.pending) }
  end

  defp start_stream(rendition, state) do
    Otis.Pipeline.Streams.start_stream(rendition, state.config, state.transcoder_module)
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
    {{:ok, data}, load_pending_stream(state)}
  end
  defp handle_data(:done, %S{pending: pending} = state) do
    case :queue.out(pending) do
      {{:value, stream}, pending} ->
        %S{ state | stream: stream, pending: pending } |> next_packet()
      {:empty, pending} ->
        {:done, %S{ state | stream: nil, pending: pending }}
    end
  end
end
