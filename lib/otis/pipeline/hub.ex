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
  alias Otis.Pipeline.Buffer
  alias Otis.Pipeline.Producer
  alias Otis.State.Rendition
  alias Otis.Library.Source

  defstruct [:id, :pid]

  defmodule S do
    @moduledoc false
    defstruct [
      :playlist,
      :packet_size,
      :packet_duration_ms,
      :transcoder_module,
      buffers: [],
    ]
  end

  def new(id, playlist, packet_size, packet_duration_ms, transcoder_module \\ Transcoder)
  def new(id, playlist, packet_size, packet_duration_ms, transcoder_module) do
    {:ok, pid} = start_link(playlist, packet_size, packet_duration_ms, transcoder_module)
    %__MODULE__{id: id, pid: pid}
  end

  def next(pid) do
    GenServer.call(pid, :next)
  end

  def start_link(playlist, packet_size, packet_duration_ms, transcoder_module) do
    GenServer.start_link(__MODULE__, [playlist, packet_size, packet_duration_ms, transcoder_module])
  end

  def init([playlist, packet_size, packet_duration_ms, transcoder_module]) do
    state = %S{
      playlist: playlist,
      packet_size: packet_size,
      packet_duration_ms: packet_duration_ms,
      transcoder_module: transcoder_module,
    } |> initialize()
    {:ok, state}
  end

  def handle_call(:next, _from, %S{buffers: [buffer | _]} = state) do
    IO.inspect Producer.next(buffer)
    {:reply, {:ok, :packet}, state}
  end

  defp initialize(state) do
    buffer = next_buffer(state)
    %S{ state | buffers: [buffer | state.buffers] }
  end

  defp next_buffer(state) do
    {:ok, rendition} = Playlist.next(state.playlist)
    source = load_source(rendition)
    stream = Source.open!(source, rendition.id, 0)
    transcoder = transcoder(rendition, source, stream, state)
    buffer = Buffer.new(rendition.id, transcoder, state.packet_size, state.packet_duration_ms, buffer_size(state))
  end

  defp transcoder(rendition, source, stream, state) do
    Kernel.apply(state.transcoder_module, :new, [rendition.id, source, stream, rendition.playback_position])
  end

  defp load_source(rendition) do
    Rendition.source(rendition)
  end

  defp buffer_size(state) do
    1000 / state.packet_duration_ms
  end
end

defimpl Otis.Pipeline.Producer, for: Otis.Pipeline.Hub do
  alias Otis.Pipeline.Hub

  def next(hub) do
    Hub.next(hub.pid)
  end
end
