use Mix.Config

config :logger, :debug_log,
  path: "log/otis.debug.log",
  level: :debug

config :logger, :console,
  level: :info,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:module, :line],
  colors: [info: :green]

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
config :porcelain, :driver, Porcelain.Driver.Goon
config :porcelain, :goon_driver_path, "#{__DIR__}/../bin/goon_darwin_amd64"

config :otis, Otis.Media,
  root: "#{__DIR__}/../_state/fs",
  at: "/fs"

import_config "#{Mix.env}.exs"

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

config :otis, :environment, :dev
