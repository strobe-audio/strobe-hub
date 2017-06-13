defmodule Peel.Migrator do
  @moduledoc """
  Ensures that all migrations are run on the Peel library db at startup.
  """

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    Ecto.Migrator.run(Peel.Repo, migrations_path(), :up, [all: true, log: :debug])
    :ignore
  end

  defp migrations_path do
    [:code.priv_dir(:peel), "repo/migrations"] |> Path.join
  end
end

