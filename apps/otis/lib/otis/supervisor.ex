defmodule Otis.Supervisor do
  use Supervisor

  def start_link(pipeline_config) do
    Supervisor.start_link(__MODULE__, pipeline_config, [])
  end

  def init(pipeline_config) do
    children = [
      {Registry, [keys: :unique, name: Otis.Registry]},
      {Otis.Mdns, pipeline_config},
      {Otis.SSDP, pipeline_config},
      {Otis.SNTP, config(Otis.SNTP)[:port]},
      Otis.Source.File.Cache,
      Otis.State.Repo,
      {Otis.State.Repo.Writer, Otis.State.Repo},
      Otis.LoggerHandler,
      Otis.State.Library,
      Otis.State.Volume,
      Otis.State.RenditionProgress,
      Otis.State.Persistence.Channels,
      Otis.State.Persistence.Receivers,
      Otis.State.Persistence.Renditions,
      Otis.State.Persistence.Playlist,
      Otis.State.Persistence.Configuration,
      Otis.Librespot.Listener,
      {Otis.Pipeline, pipeline_config}
      # This needs to be called by the app hosting the application
      # worker(Otis.Startup, [Otis.State, Otis.Channels], restart: :transient)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def config(mod) do
    Application.get_env(:otis, mod)
  end
end
