defmodule Peel.WebDAV.Supervisor do
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def enabled?(opts) do
    Keyword.get(opts, :enabled, true)
  end

  def init(opts) do
    root = ensure_docroot(opts)
    Logger.info("Starting WebDAV at root #{root}")

    children = [
      # We can run the Peel webdav on a separate port like this, but instead
      # I'm mounting it into the over-arching app using a "collections" scope
      # Plug.Adapters.Cowboy.child_spec(:http, Peel.WebDAV, [], [port: opts[:port]]),
      worker(Peel.WebDAV.Modifications, [opts])
    ]

    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

  defp ensure_docroot(opts) do
    root = Keyword.fetch!(opts, :root)
    root |> File.mkdir_p()
    # Stop macOS from attempting to index our volume
    [root, ".metadata_never_index"] |> Path.join() |> File.touch()
    root
  end
end
