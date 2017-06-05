defmodule Peel.Webdav.Supervisor do
  use     Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def enabled?(opts) do
    Keyword.get(opts, :enabled, true)
  end

  def init(opts) do
    ensure_docroot(opts)

    children = [
      # We can run the Peel webdav on a separate port like this, but instead
      # I'm mounting it into the over-arching app using a "collections" scope
      # Plug.Adapters.Cowboy.child_spec(:http, Peel.Webdav, [], [port: opts[:port]]),
      worker(Peel.Webdav.Modifications, [opts]),
    ]
    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

  defp ensure_docroot(opts) do
    Keyword.fetch!(opts, :root) |> File.mkdir_p
  end
end
