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

config :peel, Peel.Webdav,
  root: "/tmp/strobe-dav",
  port: 8080
