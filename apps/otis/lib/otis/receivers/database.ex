defmodule Otis.Receivers.Database do
  @moduledoc """
  An ETS table manager process responsible for maintaining and giving away the
  receivers database table.

  See http://steve.vinoski.net/blog/2011/03/23/dont-lose-your-ets-tables/ for
  an explanation of the pattern.
  """

  use GenServer
  require Logger

  @name Otis.Receivers.Database

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def attach(registry) do
    GenServer.cast(@name, {:attach, registry})
  end

  def init([]) do
    table =
      :ets.new(:receivers_registry, [
        :named_table,
        :set,
        {:read_concurrency, true},
        {:heir, self(), {}}
      ])

    Process.flag(:trap_exit, true)
    {:ok, table}
  end

  def handle_cast({:attach, registry}, table) do
    Process.link(registry)
    :ets.give_away(table, registry, {})
    {:noreply, table}
  end

  def handle_info({:EXIT, _from, _reason}, table) do
    Logger.info("Receivers process has crashed...")
    {:noreply, table}
  end

  def handle_info({:"ETS-TRANSFER", table, _pid, {}}, table) do
    {:noreply, table}
  end
end
