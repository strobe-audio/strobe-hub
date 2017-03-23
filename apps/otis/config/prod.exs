use Mix.Config

root_dir = Path.expand("#{__DIR__}/../../..")
state_dir = Path.join([root_dir, "_state", to_string(Mix.env)])

config :logger, :debug_log,
  path: "log/otis.debug.log",
  level: :debug

config :logger, :console,
  level: :info,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:module, :line],
  colors: [info: :green]

config :otis, :environment, :prod

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto,
  database: "/var/db/peep/otis.dev.sqlite3"

config :otis, Otis.SNTP,
  port: 5145

config :otis, Otis.Receivers,
  data_port: 5640,
  ctrl_port: 5641

config :otis, Otis.Media,
  root: "/var/db/peep/fs",
  at: "/fs"

