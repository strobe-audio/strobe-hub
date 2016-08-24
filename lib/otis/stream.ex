defmodule Otis.Stream do
  def flush(pid) do
    GenServer.call(pid, :flush)
  end
  def reset(pid) do
    GenServer.call(pid, :reset)
  end
  def resume(pid) do
    GenServer.call(pid, :resume)
  end
  def skip(pid, id) do
    GenServer.cast(pid, {:skip, id})
  end
end

