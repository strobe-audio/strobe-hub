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
  @spec open!(t, binary, non_neg_integer) :: Enumerable.t
  def open!(source, id, packet_size_bytes)

  @doc """
  Pauses the current stream.
  """
  @spec pause(t, binary, Enumerable.t) :: :ok
  def pause(source, id, stream)

  @doc """
  Resumes the current stream.
  """
  @spec pause(t, binary, Enumerable.t) :: {:reopen, Enumerable.t} | {:reuse, Enumerable.t}
  def resume!(source, id, stream)

  @doc """
  Closes the given stream.
  """
  @spec close(t, binary, Enumerable.t) :: :ok | {:error, term}
  def close(file, id, stream)

  @doc "Returns the audio type as a {extension, mime type} tuple"
  @spec audio_type(t) :: {binary, binary}
  def audio_type(source)

  @spec metadata(t) :: Otis.Source.Metadata.t
  def metadata(source)

  @spec duration(t) :: {:ok, integer} | {:ok, :infinity}
  def duration(source)
end

if Code.ensure_loaded?(Otis.Source.File) do
  defimpl Otis.Source, for: Otis.Source.File do
    alias Otis.Source.File

    def id(file) do
      file.id
    end

    def type(_file) do
      Otis.Source.File
    end

    def open!(%File{path: path}, _id, packet_size_bytes) do
      Elixir.File.stream!(path, [], packet_size_bytes)
    end

    def pause(%File{}, _id, stream) do
      :ok # no-op
    end

    def resume!(%File{}, _id, stream) do
      {:reuse, stream}
    end

    def close(%File{}, id, stream) do
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
end

if Code.ensure_loaded?(HLS.BBC.Channel) do
  defimpl Otis.Source, for: HLS.BBC.Channel do
    alias HLS.BBC

    def id(bbc) do
      bbc.id
    end

    def type(_bbc) do
      BBC.Channel
    end

    def open!(bbc, id, _packet_size_bytes) do
      BBC.open!(bbc, id)
    end

    def pause(bbc, id, stream) do
      BBC.pause(bbc, id, stream)
    end

    def resume!(bbc, id, stream) do
      BBC.resume!(bbc, id, stream)
    end

    def close(bbc, id, stream) do
      BBC.close(bbc, id, stream)
    end

    def audio_type(_bbc) do
      {".mpegts", "audio/mp2t"}
    end

    def metadata(_bbc) do
      %Otis.Source.Metadata{}
    end

    def duration(channel) do
      {:ok, channel.duration}
    end
  end

  defimpl Otis.Source.Origin, for: HLS.BBC.Channel do
    def load!(bbc) do
      HLS.BBC.find!(bbc)
    end
  end
end
