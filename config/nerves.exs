import Config

config :logger, :console,
  level: :info,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:request_id, :ip],
  colors: [info: :green]

config :elvis, Elvis.Endpoint,
  server: true,
  http: [port: 80],
  check_origin: false,
  cache_static_manifest: "priv/static/manifest.json"

# papertrail_host = System.get_env("PAPERTRAIL_SYSTEM_HOST")
# papertrail_system_name = System.get_env |> Map.get("PAPERTRAIL_SYSTEM_NAME", "unknown")

# IO.puts "===> Logging to papertrail: #{papertrail_host}/#{papertrail_system_name}"

config :otis, :environment, :prod

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto2,
  database: "/state/db/current/otis.sqlite",
  pragma: [temp_store: 2]

config :otis, Otis.SNTP, port: 5145

config :otis, Otis.Receivers,
  data_port: 5640,
  ctrl_port: 5641

config :otis, Otis.Media,
  root: "/state/fs/current",
  at: "/fs"

config :otis, Otis.State.Persistence,
  # save receiver volumes every this ms...
  volume_save_period: 1_000

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto2,
  database: "/state/db/current/peel.sqlite",
  pragma: [temp_store: 2]

config :peel, Peel.Collection,
  root: "/state/data/peel/collections",
  port: 8080

config :peel, Peel.Modifications.Create,
  # wait between getting event and testing the file status (ms)
  queue_delay: 2_000
