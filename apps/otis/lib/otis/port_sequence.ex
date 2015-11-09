defmodule Otis.PortSequence do
  @moduledoc "Provides a set of pub/sub ports to the zones"

  use     GenServer
  require Logger

  @name Otis.PortSequence

  def start_link(start_port, step) do
    GenServer.start_link(__MODULE__, [start_port, step], name: @name)
  end

  def init([start_port, step]) do
    Logger.info "Starting port sequence #{ inspect start_port } / [ #{ inspect step } ]"
    {:ok, {start_port, step, start_port}}
  end

  def next do
    next(@name)
  end

  def next(pid) do
    GenServer.call(pid, :next_port)
  end

  def handle_call(:next_port, _from, {start_port, step, port}) do
    next_port = port + step
    {:reply, {:ok, next_port}, {start_port, step, next_port}}
  end
end

