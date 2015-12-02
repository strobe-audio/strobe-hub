defprotocol Otis.Source do
  @moduledoc "Defines a protocol for extracting a stream from a source"

  @type t :: %{}

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
end

defimpl Otis.Source, for: Otis.Source.File do
  alias Otis.Source.File

  def open!(%File{path: path}, packet_size_bytes) do
    Elixir.File.stream!(path, [], packet_size_bytes)
  end

  def close(%File{}, stream) do
    Elixir.File.close(stream)
  end

  def audio_type(%File{metadata: metadata}) do
    {metadata.extension, metadata.mime_type}
  end
end

