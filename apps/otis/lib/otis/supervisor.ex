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
      worker(Otis.SNTP, []),
      worker(Otis.State, []),
      worker(Otis.PortSequence, [5040, 10]),

      :poolboy.child_spec(Otis.EmitterPool, emitter_pool_options, [
        interval: packet_interval,
        packet_size: packet_size,
        pool: Otis.EmitterPool
      ]),

      supervisor(Otis.Broadcaster, []),
      supervisor(Otis.Zones.Supervisor, []),
      worker(Otis.Zones, []),
      supervisor(Otis.Receivers.Supervisor, []),
      worker(Otis.Receivers, []),
      worker(Otis.Startup, [Otis.State, Otis.Zones, Otis.Receivers], restart: :transient)
    ]
    supervise(children, strategy: :one_for_one)
  end
end
