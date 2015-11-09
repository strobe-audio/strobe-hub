defmodule Otis.PortPool do
  @moduledoc "Provides a set of pub/sub ports to the zones"

  use     GenServer
  require Logger

  @name Otis.PortPool

  def start_link(start_port, step) do
    GenServer.start_link(__MODULE__, [start_port, step], name: @name)
  end

  def init([start_port, step]) do
    Logger.info "Starting port pool #{ inspect start_port } / [ #{ inspect step } ]"
    {:ok, {start_port, step, start_port}}
  end

  def next_port do
    next_port(@name)
  end

  def next_port(pid) do
    GenServer.call(pid, :next_port)
  end

  def handle_call(:next_port, _from, {start_port, step, port}) do
    next_port = port + step
    {:reply, {:ok, next_port}, {start_port, step, next_port}}
  end
end

