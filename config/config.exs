# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :logger, :console,
  level: :debug,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:mfa, :request_id],
  colors: [info: :green]

config :porcelain, :driver, Porcelain.Driver.Basic

# elvis
config :elvis, Elvis.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "XsNj8q0ieY/1JciZhtF6y1YX8fZLwrrD2AnCZ3LAPfcv1q0wXJjV9qXKyZ/hPYr3",
  render_errors: [accepts: ~w(html json)],
  pubsub_server: Elvis.PubSub

config :elvis, sentry_dsn: System.get_env("SENTRY_DSN")

config :phoenix, :json_library, Poison

config :otis, Otis.State.Persistence, volume_save_period: 0

config :otis_library_airplay, inputs: 2

config :peel, Peel.Modifications.Create,
  # wait between getting event and testing the file status (ms)
  queue_delay: 0

import_config "#{config_env()}.exs"
