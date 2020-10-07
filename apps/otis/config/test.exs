use Mix.Config

root_dir = Path.expand("#{__DIR__}/../../..")
state_dir = Path.join([root_dir, "_state", to_string(Mix.env())])

config :logger, :console,
  level: :error,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [],
  colors: [info: :green]

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto2,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox

config :otis, Otis.SNTP, port: 15_045

config :otis, Otis.Receivers,
  data_port: 15_540,
  ctrl_port: 15_541

config :otis, Otis.Media,
  root: Path.join([state_dir, "fs"]),
  at: "/fs"

config :otis, :environment, :test
