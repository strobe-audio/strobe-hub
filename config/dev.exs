use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :elvis, Elvis.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  cache_static_lookup: false,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/.bin/webpack",
      "--watch", "--progress", "--colors",
      "--config", "config/webpack.config.js"
   ],
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

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development.
# Do not configure such in production as keeping
# and calculating stacktraces is usually expensive.
config :phoenix, :stacktrace_depth, 20


config :otis, Otis.State.Repo,
  adapter: Sqlite.Ecto,
  database: "_state/otis.dev.sqlite3"

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto,
  database: "_state/peel.dev.sqlite3"

config :otis, Otis.SNTP,
  port: 5145

config :otis, Otis.Receivers,
  data_port: 5640,
  ctrl_port: 5641

config :porcelain, :driver, Porcelain.Driver.Goon
config :porcelain, :goon_driver_path, "/Users/garry/Seafile/Peep/peep/apps/otis/bin/goon_darwin_amd64"

