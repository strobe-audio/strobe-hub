defmodule Otis.State.Repo.Writer do
  @moduledoc """
  Serializes all writes to db through a single process to prevent contention
  propagating to the DB driver where we lose control of the consequences.
  """

  use GenServer

  require Logger

  def start_link(repo) do
    GenServer.start_link(__MODULE__, repo, name: __MODULE__)
  end

  def transaction(fun) do
    GenServer.call(__MODULE__, {:perform, fun, now()}, :infinity)
  end

  def init(repo) do
    {:ok, repo}
  end

  def handle_call({:perform, fun, queued}, _from, repo) do
    start = now()
    result = repo.transaction(fun)
    log_slow_transactions(queued, start, now())
    {:reply, result, repo}
  end

  defp now do
    DateTime.utc_now() |> DateTime.to_unix(:milliseconds)
  end

  defp log_slow_transactions(queued, start, _complete) when start - queued > 100 do
    Logger.warn "Transaction queue time #{start - queued}ms"
  end
  defp log_slow_transactions(queued, _start, complete) when complete - queued > 500 do
    Logger.warn "Transaction completion time #{complete - queued}ms"
  end
  defp log_slow_transactions(_queued, start, complete) when complete - start > 100 do
    Logger.warn "Slow transaction #{complete - start}ms"
  end
  defp log_slow_transactions(_queued, _start, _complete), do: nil
end
