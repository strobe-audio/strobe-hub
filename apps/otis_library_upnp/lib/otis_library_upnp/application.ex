defmodule Otis.Library.UPNP.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      Otis.Library.UPNP.Discovery,
      Otis.Library.UPNP.Events.Library
    ]

    opts = [strategy: :one_for_one, name: Otis.Library.UPNP.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
