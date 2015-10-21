defmodule Otis.Source.File do
  require Logger
  use     GenServer

  def from_path(path) do
    start_link(path)
  end

  def start_link(path) do
    GenServer.start_link(__MODULE__, %{path: path, outputstream: nil, inputstream: nil, transcode_pid: nil})
  end

  def handle_call(:chunk, _from, source) do
    chunk(source)
  end

  def handle_call(:source_info, _from, source) do
    {:reply, {:ok, source}, source}
  end

  def handle_cast(:pre_buffer, %{path: path} = source) do
    Logger.debug "Pre-buffering '#{path}'"
    {:noreply, open(source)}
  end

  defp chunk(%{outputstream: nil} = source) do
    chunk(open(source))
  end

  defp chunk(%{outputstream: outputstream} = source) do
    Enum.fetch(outputstream, 0) |> next_chunk(source)
  end

  defp next_chunk({:ok, _data} = chunk, source) do
    {:reply, chunk, source}
  end

  defp next_chunk(:error, source) do
    {:reply, :done, source}
  end

  defp open(source) do
    inputstream = input_stream(source)
    { pid, outputstream } = Otis.Transcoders.Avconv.transcode(inputstream, file_type(source))
    %{source | inputstream: inputstream, outputstream: outputstream, transcode_pid: pid }
  end

  defp input_stream(%{ path: path }) do
    Elixir.File.stream!(path, [], 8192)
  end

  defp file_type(%{ path: path }) do
    Path.extname(path)
  end
end

