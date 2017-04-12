defmodule HLS.Client.Stream do
  @moduledoc """
  A process for GenStage.stream to hijack its inbox
  """
  use GenServer

  def open(stream, id, opts) do
    {:ok, pid} = start_link(stream, id, opts)
    GenServer.call(pid, :stream)
  end

  def start_link(stream, id, opts) do
    GenServer.start_link(__MODULE__, [stream, id, opts])
  end

  def init([stream, id, opts]) do
    {:ok, {stream, id, opts}}
  end

  def handle_call(:stream, _from, {stream, id, opts} = state) do
    {:ok, pid} =  HLS.Client.start_link(stream, id, opts)
    stream = GenStage.stream([pid])
    {:reply, {:ok, stream}, state}
  end
end
