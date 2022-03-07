defmodule Peel do
  use Application
  require Logger

  @library_id "peel"

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    webdav_conf = Application.get_env(:peel, Peel.Collection)

    children = [
      {Finch, name: Peel.Finch},
      Peel.Repo,
      Peel.Migrator,
      Peel.Events.Library,
      {Peel.WebDAV.Supervisor, webdav_conf},
      Peel.CoverArt,
      Peel.CoverArt.EventHandler,
      Peel.CoverArt.Importer,
      {Peel.Modifications.Delete, webdav_conf},
      {Peel.Modifications.Move, webdav_conf},
      {Peel.Modifications.Create.FileStatusCheck, webdav_conf},
      {Peel.Modifications.Create, webdav_conf},
      MusicBrainz.Client,
      Peel.CoverArt.ITunes.Client
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
