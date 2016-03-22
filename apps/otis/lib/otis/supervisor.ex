defmodule Otis.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, [])
  end

  def init([packet_interval: packet_interval, packet_size: packet_size]) do
    emitter_pool_options = [
      name: {:local, Otis.EmitterPool},
      worker_module: Otis.Zone.Emitter,
      size: 16,
      max_overflow: 2
    ]

    children = [
      worker(Otis.DNSSD, []),
      worker(Otis.SNTP, [config(Otis.SNTP)[:port]]),
      worker(Otis.Source.File.Cache, []),
      worker(Otis.State.Repo, []),
      worker(Otis.State.Events, []),
      worker(Otis.State.Persistence, []),
      worker(Otis.Receivers, []),

      :poolboy.child_spec(Otis.EmitterPool, emitter_pool_options, [
        interval: packet_interval,
        packet_size: packet_size,
        pool: Otis.EmitterPool
      ]),

      supervisor(Otis.SourceStreamSupervisor, []),
      supervisor(Otis.Broadcaster, []),
      supervisor(Otis.Zones.Supervisor, []),
      supervisor(Otis.Controllers, []),
      worker(Otis.Zones, []),
      # This needs to be called by the app hosting the application
      # worker(Otis.Startup, [Otis.State, Otis.Zones], restart: :transient)
    ]
    supervise(children, strategy: :one_for_one)
  end

  def config(mod) do
    Application.get_env :otis, mod
  end
end
