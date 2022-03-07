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
      Otis.Pipeline.Streams,
      {Registry, keys: :duplicate, name: Otis.Receivers.Channels.channel_namespace()},
      {Registry, keys: :duplicate, name: Otis.Receivers.Channels.subscriber_namespace()},
      Otis.Receivers.Channels,
      Otis.Receivers.Database,
      {Otis.Receivers, [pipeline_config]},
      Otis.Receivers.Logger,
      Otis.Channels
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
