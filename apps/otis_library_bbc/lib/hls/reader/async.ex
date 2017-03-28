defmodule HLS.Reader.Async do
  use GenServer

  import HLS, only: [now: 0, read_with_timeout: 3]

  def read(reader, url, parent, id, timeout \\ 5_000) do
    HLS.Reader.Async.Supervisor.start_reader(reader, url, parent, id, now() + timeout)
  end

  def start_link(reader, url, parent, id, deadline) do
    GenServer.start_link(__MODULE__, [reader, url, parent, id, deadline], [])
  end

  ## Callbacks

  def init([reader, url, parent, id, deadline]) do
    GenServer.cast(self(), :read)
    {:ok, {reader, url, parent, id, deadline}}
  end

  def handle_cast(:read, state) do
    perform_with_timeout(state)
    {:stop, :normal, state}
  end

  defp perform_with_timeout({reader, url, _parent, _id, deadline} = state) do
    case read_with_timeout(reader, url, timeout(deadline)) do
      {:ok, {body, headers}} ->
        send_reply({:ok, body, headers}, state)
      {:exit, reason} ->
        send_reply({:error, reason}, state)
      nil ->
        send_reply({:error, :timeout}, state)
    end
  end

  defp timeout(deadline) do
    deadline - now()
  end

  defp send_reply(response, {_reader, _url, parent, id, _deadline}) do
    reply(Process.alive?(parent), parent, id, response)
  end

  defp reply(true, parent, id, response) do
    Kernel.send(parent, {id, response})
  end
  defp reply(false, _parent, _id, _response) do
  end
end
