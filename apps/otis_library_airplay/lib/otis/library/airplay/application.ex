defmodule Otis.Library.Airplay.Application do
  @moduledoc false

  use Application
  alias Otis.Library.Airplay
  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    inputs = Enum.map(Airplay.ids(), &input(&1))

    other_children = [
      worker(Otis.Library.Airplay.Events.Library, [])
    ]

    opts = [strategy: :one_for_one, name: Airplay.Supervisor]
    Supervisor.start_link(Enum.concat([inputs, other_children]), opts)
  end

  defp input(n) do
    # TODO: pass inputs a valid pipeline config
    worker(Airplay.Input, [n, :config], id: Airplay.producer_id(n))
  end
end
