import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :elvis, Elvis.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Set a higher stacktrace during test
config :phoenix, :stacktrace_depth, 20

root_dir = Path.expand("#{__DIR__}/..")
otis_state_dir = Path.join([root_dir, "_state", to_string(Mix.env())])

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
  root: Path.join([otis_state_dir, "fs"]),
  at: "/fs"

config :otis, :environment, :test

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto2,
  database: ":memory:",
  # database: Path.join(project_root_path, "_state/dev.sqlite3"),
  pool: Ecto.Adapters.SQL.Sandbox

tmp_root =
  [System.tmp_dir!(), DateTime.utc_now() |> DateTime.to_unix() |> to_string]
  |> Path.join()

config :peel, Peel.Collection,
  root: "#{tmp_root}/collections",
  port: 8090
