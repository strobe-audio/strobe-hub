defmodule Peel do
  use Application
  require Logger

  @library_id "peel"

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    webdav_conf = Application.get_env(:peel, Peel.Collection)

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Peel.Worker, [arg1, arg2, arg3]),
      worker(Peel.Repo, []),
      worker(Peel.Migrator, [], restart: :transient),
      worker(Peel.Events.Library, []),
      supervisor(Peel.WebDAV.Supervisor, [webdav_conf]),
      worker(Peel.CoverArt, []),
      worker(Peel.CoverArt.EventHandler, []),
      worker(Peel.CoverArt.Importer, []),
      worker(Peel.Modifications.Delete, [webdav_conf]),
      worker(Peel.Modifications.Move, [webdav_conf]),
      worker(Peel.Modifications.Create.FileStatusCheck, [webdav_conf]),
      worker(Peel.Modifications.Create, [webdav_conf]),
      worker(MusicBrainz.Client, []),
      worker(Peel.CoverArt.ITunes.Client, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Peel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def library_id, do: @library_id

  def scan([]) do
    Logger.info("Scan done...")
  end

  def scan([path | paths]) do
    Logger.info("Starting scan of #{inspect(path)}")
    Peel.Scanner.start(path)
    scan(paths)
  end
end
