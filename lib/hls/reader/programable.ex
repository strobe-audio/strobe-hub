defmodule HLS.Reader.Programmable do
  @moduledoc """
  A reader that can either map a single url to a sequence of files
  or fall back to the filesystem. Used for testing porpoises.
  """

  defstruct [:pid]

  def new(root, urls \\ %{})
  def new(root, urls) do
    {:ok, reader} = start_link(root: root, urls: urls)
    %__MODULE__{pid: reader}
  end

  def start_link([root: _root, urls: %{}] = opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def init(root: root, urls: urls) do
    dir_reader = HLS.Reader.Dir.new(root)
    {:ok, %{dir: dir_reader, urls: urls}}
  end

  def handle_call({:read, url}, _from, state) do
    path = HLS.Reader.Dir.path(url)
    {response, state} = read(path, Map.get(state.urls, path), state)
    {:reply, response, state}
  end

  defp read(path, nil, state) do
    body = HLS.Reader.read!(state.dir, path)
    {{:ok, body}, state}
  end

  defp read(path, [file | paths], state) do
    body = HLS.Reader.read!(state.dir, file)
    {{:ok, body}, %{ state | urls: Map.put(state.urls, path, paths) }}
  end
  defp read(_path, [], state) do
    {{:ok, ""}, state}
  end
end

defimpl HLS.Reader, for: HLS.Reader.Programmable do
  def read!(reader, url) do
    {:ok, body} = GenServer.call(reader.pid, {:read, url})
    body
  end
end
