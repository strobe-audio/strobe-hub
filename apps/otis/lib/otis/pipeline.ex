defmodule Otis.Pipeline do
  use Supervisor

  def config do
    Otis.Pipeline.Config.new(100)
  end

  def start_link(pipeline_config) do
    Supervisor.start_link(__MODULE__, pipeline_config, [])
  end

  def init(pipeline_config) do
    children = [
      supervisor(Registry, [:unique, Otis.Pipeline.Streams.namespace()], id: Otis.Pipeline.Streams.namespace()),
      supervisor(Otis.Pipeline.Streams, []),

      supervisor(Registry, [:duplicate, Otis.Receivers.Channels.channel_namespace()], id: Otis.Receivers.Channels.channel_namespace()),
      supervisor(Registry, [:duplicate, Otis.Receivers.Channels.subscriber_namespace()], id: Otis.Receivers.Channels.subscriber_namespace()),
      supervisor(Otis.Receivers.Channels, []),

      worker(Otis.Receivers.Database, []),
      worker(Otis.Receivers, [pipeline_config]),
      worker(Otis.Receivers.Logger, []),

      supervisor(Otis.Channels, []),
    ]
    supervise(children, strategy: :one_for_all)
  end
end
