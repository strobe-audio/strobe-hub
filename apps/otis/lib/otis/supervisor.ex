defmodule Otis.Supervisor do
  use Supervisor

  def start_link(pipeline_config) do
    Supervisor.start_link(__MODULE__, pipeline_config, [])
  end

  def init(pipeline_config) do
    children = [
      supervisor(Registry, [:unique, Otis.Registry], id: Otis.Registry),
      worker(Otis.Mdns, [pipeline_config]),
      worker(Otis.SSDP, [pipeline_config]),
      worker(Otis.SNTP, [config(Otis.SNTP)[:port]]),
      worker(Otis.Source.File.Cache, []),
      worker(Otis.State.Repo, []),
      worker(Otis.State.Repo.Writer, [Otis.State.Repo]),
      worker(Otis.State.Migrator, [], restart: :transient),
      worker(Otis.LoggerHandler, []),
      worker(Otis.State.Library, []),
      worker(Otis.State.Volume, []),
      worker(Otis.State.RenditionProgress, []),
      worker(Otis.State.Persistence.Channels, []),
      worker(Otis.State.Persistence.Receivers, []),
      worker(Otis.State.Persistence.Renditions, []),
      worker(Otis.State.Persistence.Playlist, []),
      worker(Otis.State.Persistence.Configuration, []),
      worker(Otis.Librespot.Listener, []),
      supervisor(Otis.Pipeline, [pipeline_config])
      # This needs to be called by the app hosting the application
      # worker(Otis.Startup, [Otis.State, Otis.Channels], restart: :transient)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def config(mod) do
    Application.get_env(:otis, mod)
  end
end
