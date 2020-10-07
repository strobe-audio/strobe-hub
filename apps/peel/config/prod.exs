use Mix.Config

config :peel, Peel.Repo,
  adapter: Sqlite.Ecto2,
  database: "/var/db/peep/peel.dev.sqlite3"

config :peel, Peel.Collection,
  root: "/mnt/Music/strobe/peel/collections",
  port: 8080
