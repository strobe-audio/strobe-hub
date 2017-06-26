defmodule Plug.WebDAV.Application do
  use Application
  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    children = [
      worker(Plug.WebDAV.Lock, []),
    ]

    opts = [strategy: :one_for_one, name: Plug.WebDAV.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
