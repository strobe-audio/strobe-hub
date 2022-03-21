defmodule Otis.Supervisor do
  use Supervisor

  def start_link(pipeline_config) do
    Supervisor.start_link(__MODULE__, pipeline_config, [])
  end

  defp service_texts(pipeline_config, port) do
    receivers = Application.get_env(:otis, Otis.Receivers)

    %{
      port: to_string(port),
      data_port: to_string(receivers[:data_port]),
      ctrl_port: to_string(receivers[:ctrl_port]),
      stream_interval: to_string(pipeline_config.packet_duration_ms * 1000),
      packet_size: to_string(pipeline_config.packet_size)
    }
    |> IO.inspect()
  end

  def init(pipeline_config) do
    {:ok, port} = Keyword.fetch(Application.get_env(:otis, Otis.SNTP), :port) |> IO.inspect()

    service =
      %Madam.Service{
        name: "strobe-hub",
        port: port,
        service: "peep-broadcaster",

        # optional data for service consumers
        data: service_texts(pipeline_config, port)
      }
      |> IO.inspect()

    children = [
      {Registry, [keys: :unique, name: Otis.Registry]},
      # {Otis.Mdns, pipeline_config},
      {Madam.Service, service: service},
      {Otis.SSDP, pipeline_config},
      {Otis.SNTP, port: config(Otis.SNTP)[:port], listeners: 20},
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
      # Otis.Librespot.Listener,
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
