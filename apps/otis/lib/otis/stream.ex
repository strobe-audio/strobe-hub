defmodule Otis.Stream do
  def flush(pid) do
    GenServer.call(pid, :flush)
  end
end

