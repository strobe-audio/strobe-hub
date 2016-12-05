defprotocol Otis.Pipeline.Producer do
  def next(producer)
end

defmodule Otis.Pipeline.Producer.Stream do
  def new(producer) do
    start = fn -> producer end
    next = fn(p) ->
      case Otis.Pipeline.Producer.next(p) do
        {:ok, data} -> {[data], p}
        :done -> {:halt, p}
      end
    end
    stop = fn(p) -> :ok end
    Stream.resource(start, next, stop)
  end
end
