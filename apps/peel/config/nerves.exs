use Mix.Config

config :logger, :console,
  level: :info,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  metadata: [:module, :line],
  colors: [enabled: false]

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
