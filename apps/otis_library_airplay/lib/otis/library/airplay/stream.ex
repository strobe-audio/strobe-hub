defmodule Otis.Library.Airplay.Stream do
  @moduledoc """
  A process for GenStage.stream to hijack its inbox
  """
  use GenServer

  defmodule S do
    @moduledoc false
    defstruct []
  end

  def start!(producer_id, config) do
    {:ok, pid} = start_link(producer_id, config)
    {:ok, stream} = GenServer.call(pid, :stream)
    stream
  end

  def start_link(producer_id, config) do
    GenServer.start_link(__MODULE__, [producer_id, config], name: :"Otis.Library.Airplay.Stream-#{producer_id}")
  end

  def init([producer_id, config]) do
    Process.flag(:trap_exit, true)
    {:ok, {producer_id, config}}
  end

  def terminate(_reason, {producer_id, _config}) do
    GenServer.cast(producer_id, :stream_stop)
    :ok
  end

  def handle_call(:stream, _from, {producer_id, _config} = state) do
    GenServer.cast(producer_id, :stream_start)
    stream = GenStage.stream([{producer_id, [max_demand: 1, cancel: :transient]}])
    {:reply, {:ok, stream}, state}
  end
end
