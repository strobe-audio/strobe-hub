use Mix.Config

project_root_path = Path.expand(Path.join(__DIR__, "../../.."))

config :logger, :console,
  level: :info,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:module, :line],
  colors: [info: :green]

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto,
  database: Path.join(project_root_path, "_state/otis.dev.sqlite3")

config :otis, Otis.SNTP,
  port: 5045

config :otis, Otis.Receivers,
  data_port: 5540,
  ctrl_port: 5541

