use Mix.Config

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto,
  database: "/var/db/peep/peel.dev.sqlite3"

