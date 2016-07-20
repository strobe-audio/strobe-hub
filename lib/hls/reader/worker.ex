defmodule HLS.Reader.Worker do
  use GenServer

  def read_with_expiry(reader, url, parent, id) do
    HLS.Reader.Worker.Supervisor.start_reader(:read_with_expiry, reader, url, parent, id)
  end
  def read(reader, url, parent, id) do
    HLS.Reader.Worker.Supervisor.start_reader(:read, reader, url, parent, id)
  end

  def start_link(mode, reader, url, parent, id) do
    GenServer.start_link(__MODULE__, [mode, reader, url, parent, id], [])
  end

  ## Callbacks

  def init([mode, reader, url, parent, id]) when mode in [:read, :read_with_expiry] do
    GenServer.cast(self(), mode)
    {:ok, {reader, url, parent, id}}
  end

  def handle_cast(:read, {reader, url, parent, id} = state) do
    response = HLS.Reader.read!(reader, url)
    reply(Process.alive?(parent), parent, id, response)
    {:stop, :normal, state}
  end
  def handle_cast(:read_with_expiry, {reader, url, parent, id} = state) do
		IO.inspect [:reader, :read_with_expiry, reader, url]
    response = HLS.Reader.read_with_expiry!(reader, url)
    reply(Process.alive?(parent), parent, id, response)
    {:stop, :normal, state}
  end

  defp reply(true, parent, id, response) do
    Kernel.send(parent, {:data, id, response})
  end
  defp reply(false, _parent, _id, _response) do
  end
end
