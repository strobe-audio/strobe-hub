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

config :otis, Otis.Media,
  root: "#{__DIR__}/../_state/fs",
  at: "/fs"

config :otis, Otis.SNTP,
  port: 5145

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox

