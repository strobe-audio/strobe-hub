use Mix.Config

# config :logger, :debug_log,
#   path: "log/otis.debug.log",
#   level: :debug

config :logger, :console,
  level: :debug,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:module, :line],
  colors: [info: :green]

config :otis, :environment, :prod

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto,
  database: "/state/db/current/otis.sqlite"

config :otis, Otis.SNTP,
  port: 5145

config :otis, Otis.Receivers,
  data_port: 5640,
  ctrl_port: 5641

config :otis, Otis.Media,
  root: "/state/fs/current",
  at: "/fs"


