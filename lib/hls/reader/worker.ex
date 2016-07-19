defmodule HLS.Reader.Worker do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def read(reader, url, parent, id) do
    pid = :poolboy.checkout(HLS.ReaderPool)
    read(pid, reader, url, parent, id)
  end

  def read(pid, reader, url, parent, id) when is_pid(pid) do
    GenServer.cast(pid, {:read, reader, url, parent, id})
  end

  ## Callbacks

  def init([pool: _pool] = opts) do
    {:ok, opts}
  end

  def handle_cast({:read, reader, url, parent, id}, [pool: pool] = state) do
    data = HLS.Reader.read!(reader, url)
    :poolboy.checkin(pool, self())
    GenServer.cast(parent, {:data, id, data})
    {:noreply, state}
  end
end
