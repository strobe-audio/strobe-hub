use Mix.Config

config :logger, :console,
  level: :error,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [],
  colors: [info: :green]

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto,
  database: ":memory:",
  # database: Path.join(project_root_path, "_state/dev.sqlite3"),
  pool: Ecto.Adapters.SQL.Sandbox

tmp_root =
  [System.tmp_dir!, DateTime.utc_now |> DateTime.to_unix |> to_string]
  |> Path.join

config :peel, Peel.Collection,
  root: "#{tmp_root}/collections",
  port: 8090
