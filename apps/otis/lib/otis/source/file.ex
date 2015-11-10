defmodule Otis.Source.File do
  require Logger
  use     GenServer

  def from_path(path) do
    start_link(path)
  end

  def start_link(path) do
    state = %{
      path: path,
      outputstream: nil,
      inputstream: nil,
      transcode_pid: nil,
      pending_streams: nil
    }
    GenServer.start_link(__MODULE__, state)
  end

  def handle_call(:chunk, _from, source) do
    chunk(source)
  end

  def handle_call(:source_info, _from, source) do
    {:reply, {:ok, source}, source}
  end

  defp chunk(%{outputstream: nil, pending_streams: nil} = source) do
    chunk(open(source))
  end

  defp chunk(%{outputstream: nil, pending_streams: {inputstream, outputstream, pid}} = source) do
    chunk(%{source | inputstream: inputstream, outputstream: outputstream, transcode_pid: pid, pending_streams: nil })
  end

  defp chunk(%{outputstream: outputstream} = source) do
    Enum.fetch(outputstream, 0) |> next_chunk(source)
  end

  defp next_chunk({:ok, _data} = chunk, source) do
    {:reply, chunk, source}
  end

  defp next_chunk(:error, %{inputstream: inputstream} = source) do
    # TODO: can I tell the transcode process to exit or will it just get GC'd
    Elixir.File.close(inputstream)
    {:reply, :done, %{source | inputstream: nil, outputstream: nil, transcode_pid: nil}}
  end

  defp open(%{pending_streams: nil} = source) do
    inputstream = input_stream(source)
    { pid, outputstream } = Otis.Transcoders.Avconv.transcode(inputstream, file_type(source))
    %{source | pending_streams: {inputstream, outputstream, pid} }
  end

  defp open(source) do
    source
  end

  defp input_stream(%{ path: path }) do
    Elixir.File.stream!(path, [], Otis.stream_bytes_per_step)
  end

  defp file_type(%{ path: path }) do
    Path.extname(path)
  end
end

