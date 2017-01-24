defmodule Otis.Supervisor do
  use Supervisor

  def start_link(pipeline_config) do
    Supervisor.start_link(__MODULE__, pipeline_config, [])
  end

  def init(pipeline_config) do
    children = [
      worker(Otis.DNSSD, [pipeline_config]),
      worker(Otis.Mdns, [pipeline_config]),
      worker(Otis.SSDP, [pipeline_config]),
      worker(Otis.SNTP, [config(Otis.SNTP)[:port]]),
      worker(Otis.Source.File.Cache, []),
      worker(Otis.State.Repo, []),
      worker(Otis.State.Events, []),
      worker(Otis.State.Persistence, []),

      supervisor(Registry, [:unique, Otis.Pipeline.Streams.namespace()], id: Otis.Pipeline.Streams.namespace()),
      supervisor(Otis.Pipeline.Streams, []),

      supervisor(Registry, [:duplicate, Otis.Receivers.Channels.channel_namespace()], id: Otis.Receivers.Channels.channel_namespace()),
      supervisor(Registry, [:duplicate, Otis.Receivers.Channels.subscriber_namespace()], id: Otis.Receivers.Channels.subscriber_namespace()),
      supervisor(Otis.Receivers.Channels, []),

      worker(Otis.Receivers.Database, []),
      worker(Otis.Receivers, [pipeline_config]),
      worker(Otis.Receivers.Logger, []),

      supervisor(Otis.Channels, []),
      # This needs to be called by the app hosting the application
      # worker(Otis.Startup, [Otis.State, Otis.Channels], restart: :transient)
    ]
    supervise(children, strategy: :one_for_all)
  end

  def config(mod) do
    Application.get_env :otis, mod
  end
end
