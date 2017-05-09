defmodule Peel.Webdav.Config do
  use     GenServer
  require Logger

  def start_link(sc, gc, opts) do
    GenServer.start_link(__MODULE__, [sc, gc, opts])
  end

  def init([sc, gc, opts]) do
    Logger.info "Starting WebDAV server at #{inspect opts[:root]} on port #{opts[:port]}"
    :yaws_api.setconf(gc, sc)
    :ignore
  end
end
