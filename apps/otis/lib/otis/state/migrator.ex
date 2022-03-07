defmodule Otis.State.Migrator do
  @moduledoc """
  Ensures that all migrations are run on the Otis state db at startup.
  """

  def run do
    Ecto.Migrator.run(Otis.State.Repo, migrations_path(), :up, all: true, log: :debug)
    :ok
  end

  defp migrations_path do
    [:code.priv_dir(:otis), "repo/migrations"] |> Path.join()
  end
end
