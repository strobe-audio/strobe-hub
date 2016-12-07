defmodule Otis.Pipeline.Producer do
  def next(%{pid: pid} = _producer) do
    next(pid)
  end
  def next(producer) do
    GenServer.call(producer, :next, :infinity)
  end

  def stop(producer) do
    GenServer.call(producer, :stop)
  end

  def pause(producer) do
    GenServer.call(producer, :pause)
  end

  def resume(producer) do
    GenServer.call(producer, :resume)
  end

  def stream(pid) do
    start = fn -> pid end
    next = fn(p) ->
      case Otis.Pipeline.Producer.next(p) do
        {:ok, data} -> {[data], p}
        :done -> {:halt, p}
      end
    end
    stop = fn(_p) -> :ok end
    Stream.resource(start, next, stop)
  end
end
