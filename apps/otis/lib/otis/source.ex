defprotocol Otis.Source do
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
  @spec open!(t, non_neg_integer) :: Enumerable.t
  def open!(source, packet_size_bytes)

  @doc """
  Returns a stream of raw PCM audio data
  """
  @spec close(t, :file.io_device) :: :ok | {:error, :file.posix | :badarg | :terminated}
  def close(file, source)

  @doc "Returns the audio type as a {extension, mime type} tuple"
  @spec audio_type(t) :: {binary, binary}
  def audio_type(source)

  @spec metadata(t) :: Otis.Source.Metadata.t
  def metadata(source)

  @spec duration(t) :: {:ok, integer} | {:ok, :infinity}
  def duration(source)
end

defimpl Otis.Source, for: Otis.Source.File do
  alias Otis.Source.File

  def id(file) do
    file.id
  end

  def type(_file) do
    Otis.Source.File
  end

  def open!(%File{path: path}, packet_size_bytes) do
    Elixir.File.stream!(path, [], packet_size_bytes)
  end

  def close(%File{}, stream) do
    Elixir.File.close(stream)
  end

  def audio_type(%File{metadata: metadata}) do
    {metadata.extension, metadata.mime_type}
  end

  def metadata(%File{metadata: metadata}) do
    metadata
  end

  def duration(%File{metadata: metadata}) do
    {:ok, metadata.duration_ms}
  end
end
