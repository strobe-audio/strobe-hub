import Config

config :logger, :console,
  level: :debug,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:mfa, :request_id, :ip],
  colors: [info: :green]

# Set a higher stacktrace during development.
# Do not configure such in production as keeping
# and calculating stacktraces is usually expensive.
config :phoenix, :stacktrace_depth, 20

config :elvis, Elvis.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  cache_static_lookup: false,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/.bin/webpack",
      "--watch",
      "--progress",
      "--colors",
      "--config",
      "config/webpack.config.js"
    ]
  ]

# Watch static and templates for browser reloading.
config :elvis, Elvis.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{web/views/.*(ex)$},
      ~r{web/templates/.*(eex)$}
    ]
  ]

root_dir = Path.expand("#{__DIR__}/..")

otis_state_dir =
  Path.join([root_dir, "_state", to_string(Mix.env())]) |> IO.inspect(label: :state_dir)

config :logger, :debug_log,
  path: "log/otis.debug.log",
  level: :debug

config :logger, :console,
  level: :debug,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:module, :line],
  colors: [info: :green]

config :otis, :environment, :dev

config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto2,
  database: Path.join([otis_state_dir, "otis.dev.sqlite3"]),
  pragma: []

config :otis, Otis.SNTP, port: 5045

config :otis, Otis.Receivers,
  data_port: 5540,
  ctrl_port: 5541

config :otis, Otis.Media,
  root: Path.join([otis_state_dir, "fs"]),
  at: "/fs"

peel_state_dir = Path.join([root_dir, "_state", to_string(Mix.env())])

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto2,
  database: Path.join([peel_state_dir, "peel.dev.sqlite3"])

config :peel, Peel.Collection,
  root: Path.join([peel_state_dir, "collections"]),
  port: 8888

config :plug_webdav, Plug.WebDAV.Handler,
  port: 5555,
  root: "/tmp/plug-webdav"
