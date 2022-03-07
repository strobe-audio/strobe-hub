import Config

papertrail_host = System.get_env("PAPERTRAIL_SYSTEM_HOST")
papertrail_system_name = System.get_env() |> Map.get("PAPERTRAIL_SYSTEM_NAME", "unknown")

IO.puts("===> Logging to papertrail: #{papertrail_host}/#{papertrail_system_name}")

config :logger,
  backends: [:console, LoggerPapertrailBackend.Logger],
  level: :info

config :logger, :logger_papertrail_backend,
  host: papertrail_host,
  system_name: papertrail_system_name,
  level: :debug,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  metadata: [:module, :line]

config :elvis, Elvis.Endpoint,
  server: true,
  http: [port: {:system, "PORT"}],
  # http: [port: 4000],
  # url: [host: "192.168.1.67", port: 4000],
  check_origin: false,
  cache_static_manifest: "priv/static/manifest.json"

root_dir = Path.expand("#{__DIR__}/..") |> IO.inspect(label: :root_dir)

_otis_state_dir =
  Path.join([root_dir, "_state", to_string(Mix.env())]) |> IO.inspect(label: :state_dir)

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
  adapter: Sqlite.Ecto2,
  database: "/var/db/peep/otis.dev.sqlite3"

config :otis, Otis.SNTP, port: 5145

config :otis, Otis.Receivers,
  data_port: 5640,
  ctrl_port: 5641

config :otis, Otis.Media,
  root: "/var/db/peep/fs",
  at: "/fs"

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto2,
  database: "/var/db/peep/peel.dev.sqlite3"

config :peel, Peel.Collection,
  root: "/mnt/Music/strobe/peel/collections",
  port: 8080
