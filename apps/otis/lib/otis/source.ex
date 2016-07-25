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

  @spec metadata(t) :: Map.t
  def metadata(source)

  @spec duration(t) :: {:ok, integer} | {:ok, :infinity}
  def duration(source)
end

# :(
# This is the best I can do for the moment without working out a proper code
# loading system. The question is, how to implement the protocol from one
# module in another completely separate one?
#
# I could do it with an umbrella app, but that would limit source
# implementations to those in that umbrella app.
defimpl Otis.Source, for: BBC.Channel do
  defdelegate id(source), to: BBC.Source
  defdelegate type(source), to: BBC.Source
  defdelegate open!(source, id, packet_size_bytes), to: BBC.Source
  defdelegate pause(source, id, stream), to: BBC.Source
  defdelegate resume!(source, id, stream), to: BBC.Source
  defdelegate close(file, id, stream), to: BBC.Source
  defdelegate audio_type(source), to: BBC.Source
  defdelegate metadata(source), to: BBC.Source
  defdelegate duration(source), to: BBC.Source
end

defimpl Otis.Source.Origin, for: BBC.Channel do
  defdelegate load!(source), to: BBC.Source.Origin
end
