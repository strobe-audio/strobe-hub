defmodule Otis.SourceStream do
  require Logger
  use     GenServer

  @doc "Gives the next chunk of datea from the source"
  def chunk(pid) do
    GenServer.call(pid, :chunk)
  end

  @doc """
  Returns info about the current source. This will vary according to the source
  type but should conform to some kind of as-yet-determined api.
  """
  def info(pid) do
    GenServer.call(pid, :source_info)
  end

  # TODO: remove this!
  def from_path(path) when is_binary(path) do
    new(path)
  end

  def new({:ok, stream}) do
    new(stream)
  end

  def new(stream) do
    start_link(stream)
  end

  def start_link(stream) do
    state = %{
      stream: stream,
      outputstream: nil,
      inputstream: nil,
      transcode_pid: nil,
      pending_streams: nil
    }
    GenServer.start_link(__MODULE__, state)
  end

  def handle_call(:chunk, _from, state) do
    next_chunk(state)
  end

  def handle_call(:source_info, _from, state) do
    {:reply, {:ok, state.stream}, state}
  end

  defp next_chunk(%{outputstream: nil, pending_streams: nil} = state) do
    next_chunk(open(state))
  end

  defp next_chunk(%{outputstream: nil, pending_streams: {inputstream, outputstream, pid}} = state) do
    next_chunk(%{state | inputstream: inputstream, outputstream: outputstream, transcode_pid: pid, pending_streams: nil })
  end

  defp next_chunk(%{outputstream: outputstream} = state) do
    Enum.fetch(outputstream, 0) |> next_chunk(state)
  end

  defp next_chunk({:ok, _} = chunk, state) do
    {:reply, chunk, state}
  end

  defp next_chunk(:error, %{stream: stream, inputstream: inputstream} = state) do
    # TODO: can I tell the transcode process to exit or will it just get GC'd
    Otis.Source.Stream.close(stream, inputstream)
    {:reply, :done, %{state | inputstream: nil, outputstream: nil, transcode_pid: nil}}
  end

  defp open(%{pending_streams: nil} = state) do
    inputstream = input_stream(state)
    { pid, outputstream } = Otis.Transcoders.Avconv.transcode(inputstream, stream_type(state))
    %{state | pending_streams: {inputstream, outputstream, pid} }
  end

  defp open(state) do
    state
  end

  defp input_stream(%{ stream: stream }) do
    Otis.Source.Stream.open!(stream, Otis.stream_bytes_per_step * 4)
  end

  defp stream_type(%{ stream: stream }) do
    {ext, _mime_type} = Otis.Source.Stream.audio_type(stream)
    ext
  end
end
