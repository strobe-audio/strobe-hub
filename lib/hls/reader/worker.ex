defmodule HLS.Reader.Worker do
  use GenServer

  def read(reader, url, parent, id) do
    HLS.Reader.Worker.Supervisor.start_reader(reader, url, parent, id)
  end

  def start_link(reader, url, parent, id) do
    GenServer.start_link(__MODULE__, [reader, url, parent, id], [])
  end

  ## Callbacks

  def init([reader, url, parent, id]) do
    GenServer.cast(self(), :read)
    {:ok, {reader, url, parent, id}}
  end

  def handle_cast(:read, {reader, url, parent, id} = state) do
    response = HLS.Reader.read!(reader, url)
    reply(Process.alive?(parent), parent, id, response)
    {:stop, :normal, state}
  end

  defp reply(true, parent, id, response) do
    Kernel.send(parent, {:data, id, response})
  end
  defp reply(false, _parent, _id, _response) do
  end
end
