defmodule Otis.Source.File.Cache do
  @moduledoc """
  In dev mode Source.File lookup is slow enough that having a lot of sources
  means initialization can take a long time. This wraps the file metadata
  lookup with a cache to avoid that problem.
  """

  use GenServer
  require Logger

  @name Otis.Source.File.Cache
  @table Otis.Source.File.Cache

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def lookup(path, lookup) do
    case :ets.lookup(@table, path) do
      [{^path, source}] ->
        Logger.debug("Cache hit #{inspect(path)}...")
        source

      [] ->
        create_insert(path, lookup)
    end
  end

  def create_insert(path, lookup) do
    GenServer.call(@name, {:create_insert, path, lookup})
  end

  def init([]) do
    table = :ets.new(@table, [:named_table, read_concurrency: true])
    {:ok, table}
  end

  def handle_call({:create_insert, path, lookup}, _from, table) do
    Logger.debug("Cache miss #{inspect(path)}...")
    source = lookup.()
    :ets.insert(table, {path, source})
    {:reply, source, table}
  end
end
