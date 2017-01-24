defmodule Otis.State.Events do
  @moduledoc """
  The centralised event stream that any object interested in the state of the
  app should subscribe to and all state change events should be sent to.
  """

  require Logger

  @name Otis.State.Events

  def start_link do
    Logger.info "Starting #{ __MODULE__ }..."
    GenEvent.start_link(name: @name)
  end

  def notify(event) do
    GenEvent.notify(@name, event)
  end

  def ack_notify(event) do
    GenEvent.ack_notify(@name, event)
  end

  def sync_notify(event) do
    GenEvent.sync_notify(@name, event)
  end

  def call(handler, request, timeout \\ 5000) do
    GenEvent.call(@name, handler, request, timeout)
  end

  def add_handler(handler, args) do
    GenEvent.add_handler(@name, handler, args)
  end

  def add_mon_handler(handler, args) do
    GenEvent.add_mon_handler(@name, handler, args)
  end

  def remove_handler(handler, args \\ :remove_handler)
  def remove_handler(handler, args) do
    GenEvent.remove_handler(@name, handler, args)
  end

  def stream(options \\ []) do
    GenEvent.stream(@name, options)
  end

  def which_handlers do
    GenEvent.which_handlers(@name)
  end
end
