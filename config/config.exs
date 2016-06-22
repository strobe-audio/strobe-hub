# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :elvis, Elvis.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "XsNj8q0ieY/1JciZhtF6y1YX8fZLwrrD2AnCZ3LAPfcv1q0wXJjV9qXKyZ/hPYr3",
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Elvis.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :otis, Otis.Media,
  root: "#{__DIR__}/../_state/fs",
  at: "/fs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
