defmodule HLS.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, [])
  end

  def init(_opts) do
    pool_name = HLS.ReaderPool

    reader_pool_options = [
      name: {:local, pool_name},
      worker_module: HLS.Reader.Worker,
      size: 16,
      max_overflow: 2
    ]

    children = [
      supervisor(HLS.DataStream.Supervisor, []),
      :poolboy.child_spec(pool_name, reader_pool_options, [
        pool: pool_name
      ]),
    ]
    supervise(children, strategy: :one_for_one)
  end

end
