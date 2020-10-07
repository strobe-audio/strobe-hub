use Mix.Config

root_dir = Path.expand("#{__DIR__}/../../..")
state_dir = Path.join([root_dir, "_state", to_string(Mix.env())]) |> IO.inspect(label: :state_dir)

config :logger, :debug_log,
  path: "log/otis.debug.log",
  level: :debug

config :logger, :console,
  level: :info,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:module, :line],
  colors: [info: :green]

config :otis, :environment, :dev

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto2,
  database: Path.join([state_dir, "otis.dev.sqlite3"]),
  pragma: []

config :otis, Otis.SNTP, port: 5045

config :otis, Otis.Receivers,
  data_port: 5540,
  ctrl_port: 5541

config :otis, Otis.Media,
  root: Path.join([state_dir, "fs"]),
  at: "/fs"
