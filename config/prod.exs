import Config

papertrail_host = System.get_env("PAPERTRAIL_SYSTEM_HOST", nil)
papertrail_system_name = System.get_env() |> Map.get("PAPERTRAIL_SYSTEM_NAME", "unknown")

backends =
  if is_nil(papertrail_host) do
    [:console]
  else
    IO.puts("===> Logging to papertrail: #{papertrail_host}/#{papertrail_system_name}")

    config :logger, :logger_papertrail_backend,
      host: papertrail_host,
      system_name: papertrail_system_name,
      level: :debug,
      format: "$date $time $metadata [$level]$levelpad $message\n",
      metadata: [:module, :line]

    [:console, LoggerPapertrailBackend.Logger]
  end

config :logger,
  backends: backends,
  level: :info

config :elvis, Elvis.Endpoint,
  server: true,
  http: [port: {:system, "PORT", 4000}],
  # http: [port: 4000],
  # url: [host: "192.168.1.67", port: 4000],
  check_origin: false,
  cache_static_manifest: "priv/static/cache_manifest.json"

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

db_root = System.get_env("STROBE_DB_PATH", "/var/db/strobe") |> IO.inspect(label: :db_root)

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto2,
  database: Path.join(db_root, "otis.prod.sqlite3")

config :otis, Otis.SNTP, port: 5145

config :otis, Otis.Receivers,
  data_port: 5640,
  ctrl_port: 5641

config :otis, Otis.Media,
  root: Path.join(db_root, "fs"),
  at: "/fs"

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto2,
  database: Path.join(db_root, "peel.prod.sqlite3")

config :peel, Peel.Collection,
  root: "/mnt/Music/strobe/peel/collections",
  port: 8080
