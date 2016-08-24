use Mix.Config

config :logger, :console,
  level: :error,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [],
  colors: [info: :green]

project_root_path = Path.expand(Path.join(__DIR__, "../../.."))

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto,
  database: ":memory:",
  # database: Path.join(project_root_path, "_state/dev.sqlite3"),
  pool: Ecto.Adapters.SQL.Sandbox

config :otis, Otis.SNTP,
  port: 15045

config :otis, Otis.Receivers,
  data_port: 15540,
  ctrl_port: 15541

