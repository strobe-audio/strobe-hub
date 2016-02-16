use Mix.Config

config :logger, :console,
  level: :debug,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [],
  colors: [info: :green]

project_root_path = Path.expand(Path.join(__DIR__, "../../.."))

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto,
  database: ":memory:",
  # database: Path.join(project_root_path, "_state/dev.sqlite3"),
  pool: Ecto.Adapters.SQL.Sandbox
