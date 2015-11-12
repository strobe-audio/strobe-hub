defmodule Otis.Source.File do
  require Logger
  use     GenServer
  alias   Otis.Filesystem.File, as: F

  def from_path(path) do
    new(path)
  end

  def new(path) when is_binary(path) do
    F.new(path) |> new
  end

  def new({:ok, %F{} = file}) do
    new(file)
  end

  def new(%F{} = file) do
    start_link(file)
  end

  def start_link(%F{} = file) do
    state = %{
      file: file,
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

  defp input_stream(%{ file: file }) do
    Elixir.File.stream!(file.path, [], Otis.stream_bytes_per_step)
  end

  defp file_type(%{ file: file }) do
    F.extension(file)
  end
end

