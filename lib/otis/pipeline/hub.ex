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
      streams: [],
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

  def handle_call(:next, _from, %S{streams: [stream | _]} = state) do
    IO.inspect Producer.next(stream)
    {:reply, {:ok, :packet}, state}
  end

  defp initialize(state) do
    # TODO: replace :next with :current which returns either :active or the first
    {:ok, rendition} = Playlist.next(state.playlist)
    {:ok, stream} = start_stream(rendition, state)
    %S{ state | streams: [stream | state.streams] }
  end

  defp start_stream(rendition, state) do
    Otis.Pipeline.Streams.start_stream(rendition, state.config, state.transcoder_module)
  end
end
