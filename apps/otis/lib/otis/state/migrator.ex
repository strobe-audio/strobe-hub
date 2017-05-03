defmodule Otis.State.Migrator do
  @moduledoc """
  Ensures that all migrations are run on the Otis state db at startup.
  """

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    Ecto.Migrator.run(Otis.State.Repo, migrations_path(), :up, [all: true, log: :debug])
    :ignore
  end

  defp migrations_path do
    [:code.priv_dir(:otis), "repo/migrations"] |> Path.join
  end
end
