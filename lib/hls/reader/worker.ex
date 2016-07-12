defmodule HLS.Reader.Worker do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def read(pid, reader, url, parent, id) do
    GenServer.cast(pid, {:read, reader, url, parent, id})
  end

  ## Callbacks

  def init([pool: _pool] = opts) do
    {:ok, opts}
  end

  def handle_cast({:read, reader, url, parent, id}, [pool: pool] = state) do
    data = HLS.Reader.read!(reader, url)
    GenServer.cast(parent, {:data, id, data})
    :poolboy.checkin(pool, self())
    {:noreply, state}
  end
end
