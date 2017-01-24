defprotocol Otis.Library.Source do
  @moduledoc "Defines a protocol for extracting a stream from a source"

  @type t :: %{}

  @doc """
  Returns the source's unique id
  """
  @spec id(t) :: binary
  def id(source)

  @spec type(t) :: atom
  def type(source)

  @doc """
  Returns a stream of raw PCM audio data
  """
  @spec open!(t, binary, non_neg_integer) :: Enumerable.t
  def open!(source, id, packet_size_bytes)

  @doc """
  Pauses the current stream. If the stream is live and cannot be resumed
  without reloading then it should return :stop so the audio pipeline can shut
  it down and restart it when required.
  """
  @spec pause(t, binary, Enumerable.t) :: :ok | :stop
  def pause(source, id, stream)

  @doc """
  Closes the given stream.
  """
  @spec close(t, binary, Enumerable.t) :: :ok | {:error, term}
  def close(file, id, stream)

  @doc "Returns the audio type as a {extension, mime type} tuple"
  @spec audio_type(t) :: {binary, binary}
  def audio_type(source)

  @spec metadata(t) :: Map.t
  def metadata(source)

  @spec duration(t) :: {:ok, integer} | {:ok, :infinity}
  def duration(source)
end
